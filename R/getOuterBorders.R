#' @title Extract Polygons Outer Borders
#' @description Extract outer borders between polygons.
#' Outer borders are non-contiguous polygons borders (e.g.
#' maritim borders).
#' @name getOuterBorders
#' @param x an sf object, a simple feature collection or a SpatialPolygonsDataFrame.
#' @param id identifier field in x, default to the first column. (optional)
#' @param res resolution of the grid used to compute borders (in x units).
#' A high resolution will give more detailed borders. (optional)
#' @param width maximum distance between used to compute borders (in x units).
#' A higher width will build borders between units that are farther apart. (optional)
#' @param spdf deprecated, a SpatialPolygonsDataFrame. This SpatialPolygonsDataFrame
#'  has to be projected (planar coordinates).
#' @param spdfid deprecated, identifier field in spdf, default to the first column 
#' of the spdf data frame.  (optional)
#' @return An sf object (MULTILINESTRING) of borders is returned. This object has three
#' id fields: id, id1 and id2.
#' id1 and id2 are ids of units that neighbour a border; id is the concatenation
#' of id1 and id2 (with "_" as separator).
#' @note getBorders and getOuterBorders can be combined with rbind.
#' @examples
#' mtq <- st_read(system.file("shape/martinique.shp", package="cartography"))
#' # Get units borders
#' mtq.outer <- getOuterBorders(x = mtq, res = 1000, width = 2500)
#' # Plot communesa
#' plot(mtq$geometry, col = "grey60")
#' # Plot borders
#' plot(mtq.outer, col = sample(x = rainbow(nrow(mtq.outer))),
#'      lwd = 3, add = TRUE)
#'      
#' \donttest{
#' data(nuts2006)
#' # Get units borders
#' nuts0.outer <- getOuterBorders(x = nuts0.spdf)
#' # Plot Countries
#' plot(nuts0.spdf, border = NA, col = "grey60")
#' # Plot borders
#' plot(nuts0.outer, col = sample(x = rainbow(nrow(nuts0.outer))),
#'      lwd = 3, add = TRUE)
#' }
#' @seealso \link{discLayer}, \link{getBorders}
#' @export
getOuterBorders <- function(x, id, res = NULL, width = NULL, spdf, spdfid = NULL){
  
  if(sum(missing(spdf), is.null(spdfid)) != 2){
    warning("spdf and spdfid are deprecated; use x and id instead.", call. = FALSE)
  }
  
  if(!missing(x)){
    if(methods::is(x,'sf')){
      spdf <- methods::as(x, "Spatial")
    }else{
      spdf <- x
    }
  }
  if(!is.null(spdfid)){
    id <- spdfid
  }
  if (missing(id)) {
    id <- names(spdf@data)[1]
  }
  
  if(!is.numeric(spdf[,id])){
    spdf$idxd <- 1:nrow(spdf)
  }else{
    spdf$idxd <- spdf@data[, id]
  }
  

  
  boundingBox <- sp::bbox(spdf)
  w <- (boundingBox[1,2] - boundingBox[1,1])
  h <- (boundingBox[2,2] - boundingBox[2,1])
  
  
  if(is.null(res)){
    res <- round(max(c(w, h))/150,0)
  }
  
  if(is.null(width)){
    width <- round(max(c(w, h))/20,0)
  }
  
  
  # Create raster of spdf
  ex <- raster::extent(spdf)
  ex[1] <- ex[1] - width
  ex[2] <- ex[2] + width
  ex[3] <- ex[3] - width
  ex[4] <- ex[4] + width
  
  r <- raster::raster(ex, resolution = res)
  
  r <- raster::rasterize( x= spdf,  y=r, field = 'idxd')
  
  dist <- raster::distance(r)
  dist[dist > width] <- NA
  # you can also set a maximum distance: dist[dist > maxdist] <- NA
  direct <- raster::direction(r, from=FALSE)
  
  # NA raster
  rna <- is.na(r) # returns NA raster
  
  # store coordinates in new raster: http://stackoverflow.com/a/35592230/3752258
  na.x <- raster::init(rna, 'x')
  na.y <- raster::init(rna, 'y')
  
  
  # calculate coordinates of the nearest Non-NA pixel
  # assume that we have a orthogonal, projected CRS, so we can use (Pythagorean) calculations
  co.x <- na.x + dist * sin(direct)
  co.y <- na.y + dist * cos(direct)
  
  # matrix with point coordinates of nearest non-NA pixel
  co <- cbind(co.x[], co.y[])
  
  
  # extract values of nearest non-NA cell with coordinates co
  NAVals <- raster::extract(r, co, method='simple')
  r.NAVals <- rna # initiate new raster
  r.NAVals[] <- NAVals # store values in raster
  
  pB <- raster::rasterToPolygons(r.NAVals, dissolve = T)
  pB@data$id <- spdf@data[pB@data$layer, id]
  
  
  pBBorder <- getBorders(x = pB, id = "id" )
  result <- st_simplify(x=pBBorder, dTolerance = res, preserveTopology = F)
  row.names(result) <- paste0(row.names(result), "_o")
  
  
  
  return(result)
}
