# ===============================================================================
#
# PROGRAMMERS:
#
# jean-romain.roussel.1@ulaval.ca  -  https://github.com/Jean-Romain/lidR
#
# COPYRIGHT:
#
# Copyright 2016-2018 Jean-Romain Roussel
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

if (!isGeneric("summary"))
  setGeneric("summary", function(object, ...)
    standardGeneric("summary"))

if (!isGeneric("print"))
  setGeneric("print", function(x, ...)
    standardGeneric("print"))

#' Plot a LAS* object
#'
#' Plot displays a 3D interactive windows based on rgl for \link{LAS} objects
#'
#' @param x A \code{LAS*} object
#' @param y Unused (inherited from R base)
#' @param color characters. The field used to color the points. Default is Z coordinates.
#' @param colorPalette characters. A list of colors such as that generated by heat.colors,
#' topo.colors, terrain.colors or similar functions.  Default is \code{height.colors(50)}
#' provided by the package \code{lidR}
#' @param bg The color for the background. Default is black.
#' @param trim numeric. Enables trimming of values when outliers break the color palette range.
#' Default is 1, meaning that the whole range of values is used for the color palette.
#' 0.9 means that 10\% of the highest values are not used to define the color palette.
#' In this case values higher than the 90th percentile are set to the highest color.
#' They are not removed.
#' @param backend character. Can be \code{"rgl"} or \code{"pcv"}. If \code{"rgl"} is chosen
#' the display relies on the \code{rgl} package. If \code{"pcv"} is chosen it relies on the
#' \code{PointCloudViewer} package which is much more efficient and can handle million of points
#' using few memory. \code{PointCloudViewer} is not available on CRAN yet and should
#' be install from github (see. \url{https://github.com/Jean-Romain/PointCloudViewer}).
#' @param ... Will be passed to \link[rgl:points3d]{points3d} (LAS) or \link[graphics:plot]{plot}
#' if \code{mapview = FALSE} or to \link[mapview:mapView]{mapview} if \code{mapview = TRUE} (LAScatalog).
#' @examples
#' LASfile <- system.file("extdata", "Megaplot.laz", package="lidR")
#' las = readLAS(LASfile)
#'
#' plot(las)
#'
#' # Outliers of intensity breaks the color range. Use the trim parameter.
#' plot(las, color = "Intensity", colorPalette = heat.colors(50))
#' plot(las, color = "Intensity", colorPalette = heat.colors(50), trim = 0.99)
#' @export
#' @method plot LAS
setGeneric("plot", function(x, y, ...)
  standardGeneric("plot"))

#' Test if a \code{LAS} object is empty
#'
#' An empty \code{LAS} object is a point cloud with 0 points
#'
#' @param object A \code{LAS} object
#' @param ... Unused
#'
#' @return TRUE or FALSE
#' @examples
#' LASfile <- system.file("extdata", "example.laz", package="rlas")
#' las = readLAS(LASfile)
#' is.empty(las)
#'
#' las = new("LAS")
#' is.empty(las)
#' @export
setGeneric("is.empty", function(object, ...)
  standardGeneric("is.empty"))

#' Surface covered by a LAS* object.
#'
#' Surface covered by a \code{LAS*} object. For \code{LAS} point cloud it is computed based on the
#' convex hull of the points. For a \code{LAScatalog} it is computed a the sum of the bounding box
#' of the files. For overlaping tiles the value may be larger that the total covered area because
#' some regions are sampled twice.
#'
#' @param x An object of the class \code{LAS*}
#' @param ... unused
#'
#' @return numeric. The area of the object computed in the same units as the coordinate reference system
#' @export
#' @importMethodsFrom raster area
#' @rdname area
setGeneric("area", function(x, ...)
  standardGeneric("area"))