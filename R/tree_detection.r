# ===============================================================================
#
# PROGRAMMERS:
#
# jean-romain.roussel.1@ulaval.ca  -  https://github.com/Jean-Romain/lidR
#
# COPYRIGHT:
#
# Copyright 2017 Jean-Romain Roussel
#
# This file is part of lidR R package.
#
# lidR is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>
#
# ===============================================================================

#' Tree top detection
#'
#' This function is a wrapper for all the implemented tree detection methods. Tree dectection function
#' find the position of the trees before the segmentation process. Several methods may be used
#' (see documentation of each method)
#'
#' @param x A object of class \code{LAS} or an object representing a canopy height model
#' such as a \code{RasterLayer} or a \code{lasmetrics} or a \code{matrix} depending on the algorithm
#' used (see respective documentation)
#' @param algorithm character. Can be either \code{"lmf"} or \code{"ptree"}.
#' @param ... Other parameters for each respective algorithm (see section "see also".
#'
#' @return The output of each algorithm as documented in each method.
#' @export
#'
#' @examples
#' LASfile <- system.file("extdata", "MixedConifer.laz", package="lidR")
#' las = readLAS(LASfile, select = "xyz", filter = "-drop_z_below 0")
#'
#' ttops = tree_detection(las, "lmf", ws = 5)
#'
#' plot(las)
#' with(ttops, rgl::points3d(X, Y, Z, col = "red", size = 5, add = TRUE))
#' @seealso \link{tree_detection_lmf} \link{tree_detection_ptree}
tree_detection = function(x, algorithm, ...)
{
  if (algorithm == "lmf")
    tree_detection_lmf(x, ...)
  else if (algorithm == "ptree")
    tree_detection_ptree(x, ...)
  else
    stop("This algorithm does not exist.", call. = FALSE)
}

#' Tree top detection based local maxima filters
#'
#' Tree top detection based on fixed windows size local maxima filters. There are two types of filters.
#' The first one, called for gridded objects, works on images with a matrix-based algorithm
#' and the second one, called for point clouds, works at the point cloud level without any
#' rasterization.
#'
#' @param x A object of class \code{LAS} or an object representing a canopy height model
#' such as a \code{RasterLayer} or a \code{lasmetrics} or a \code{matrix}.
#' @param ws numeric. Size of the moving window used to the detect the local maxima. On
#' a raster-like object this size is in pixels and should be an odd number larger than 3.
#' On a raw point cloud this size is in the point cloud units (usually meters).
#' @param hmin numeric. Minimum height of a tree. Threshold below which a pixel or a point
#' cannot be a local maxima. Default 2.
#'
#' @return A \code{data.table} with the coordinates of the tree tops (X, Y, Z) if the input
#' is a point cloud, or a RasterLayer if the input is a raster-like object.
#' @export
#'
#' @examples
#' LASfile <- system.file("extdata", "MixedConifer.laz", package="lidR")
#' las = readLAS(LASfile, select = "xyz", filter = "-drop_z_below 0")
#'
#' # point-cloud-based method
#'
#' ttops = tree_detection(las, 5)
#'
#' plot(las)
#' with(ttops, rgl::points3d(X, Y, Z, col = "red", size = 5, add = TRUE))
#'
#' # raster-based method
#'
#' chm = grid_canopy(las, 1, subcircle = 0.15)
#' chm = as.raster(chm)
#' kernel = matrix(1,3,3)
#' chm = raster::focal(chm, w = kernel, fun = median, na.rm = TRUE)
#'
#' ttops = tree_detection(chm, 5)
#'
#' raster::plot(chm, col = height.colors(30))
#' raster::plot(ttops, add = TRUE, col = "black", legend = FALSE)
tree_detection_lmf = function(x, ws, hmin = 2)
{
  UseMethod("tree_detection_lmf", x)
}

#' @export
tree_detection_lmf.LAS = function(x, ws, hmin = 2)
{
  assertive::assert_is_a_number(ws)
  assertive::assert_all_are_positive(ws)
  assertive::assert_is_a_number(hmin)
  assertive::assert_all_are_positive(hmin)

  . <- X <- Y <- Z <- NULL
  maxima = C_LocalMaximaPoints(x, ws, hmin)
  return(x@data[maxima, .(X,Y,Z)])
}

#' @export
tree_detection_lmf.lasmetrics = function(x, ws, hmin = 2)
{
  assertive::assert_is_a_number(ws)
  assertive::assert_all_are_positive(ws)
  assertive::assert_is_a_number(hmin)
  assertive::assert_all_are_positive(hmin)

  x = as.raster(x)
  return(tree_detection_lmf.RasterLayer(x, ws, hmin))
}

#' @export
tree_detection_lmf.RasterLayer = function(x, ws, hmin = 2)
{
  assertive::assert_is_a_number(ws)
  assertive::assert_all_are_positive(ws)
  assertive::assert_is_a_number(hmin)
  assertive::assert_all_are_positive(hmin)

  xx <- raster::as.matrix(x)
  xx <- t(apply(xx, 2, rev))
  LM = tree_detection_lmf.matrix(xx, ws, hmin)
  LM = raster::raster(apply(LM,1,rev))
  raster::extent(LM) = raster::extent(x)
  return(LM)
}

#'@export
tree_detection_lmf.matrix = function(x, ws, hmin = 2)
{
  assertive::assert_is_a_number(ws)
  assertive::assert_all_are_greater_than_or_equal_to(ws, 3)
  assertive::assert_all_are_odd(ws)

  x[is.na(x)] <- -Inf
  LM = C_LocalMaximaMatrix(x, ws, hmin)
  LM[LM == 0] <- NA
  return(LM)
}

#' @rdname lastrees_ptrees
#' @aliases tree_detection_ptree
tree_detection_ptrees = function(las, k, hmin = 3, nmax = 7L)
{
  stopifnotlas(las)
  assertive::assert_is_numeric(k)
  assertive::assert_all_are_positive(k)
  assertive::assert_all_are_whole_numbers(k)
  assertive::assert_is_a_number(nmax)
  assertive::assert_all_are_whole_numbers(nmax)

  TreeSegments = C_lastrees_ptrees(las, k, hmin, nmax, FALSE)
  apices = TreeSegments$Apices
  apices = data.table::as.data.table(apices)
  data.table::setnames(apices, names(apices), c("X", "Y", "Z"))
  return(apices)
}

