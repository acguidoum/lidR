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

catalog_makecluster = function(ctg)
{
  xmin    <- ymin <- xmax <- ymax <- 0
  buffer  <- get_buffer(ctg)
  by_file <- get_by_file(ctg)
  start   <- get_alignment(ctg)
  width   <- get_tiling_size(ctg)

  # Creation of a set rectangle that encompass the catalog
  # =======================================================

  if (by_file)
  {
    xmin = ctg@data$`Min X`
    xmax = ctg@data$`Max X`
    ymin = ctg@data$`Min Y`
    ymax = ctg@data$`Max Y`
  }
  else
  {
    # Bounding box of the catalog
    bbox = with(ctg@data, c(min(`Min X`), min(`Min Y`), max(`Max X`), max(`Max Y`)))

    # Shift to align the grid
    shift = numeric(2)
    shift[1] = (bbox[1] - start[1]) %% width
    shift[2] = (bbox[2] - start[2]) %% width

    # Generate coordinates of bottom left clusters corners
    xmin = seq(bbox[1] - shift[1], bbox[3], width)
    ymin = seq(bbox[2] - shift[2], bbox[4], width)
    grid = expand.grid(xmin = xmin, ymin = ymin)
    xmin = grid$xmin
    ymin = grid$ymin
    xmax = xmin + width
    ymax = ymin + width
  }

  verbose("Creating a set of cluster for the catalog...")

  xcenter = (xmin + xmax)/2
  ycenter = (ymin + ymax)/2
  width   = xmax - xmin
  height  = ymax - ymin

  # Creation of a set of cluster from the rectangles
  # ================================================

  if (by_file & buffer <= 0)
  {
    clusters = lapply(1:length(xcenter), function(i)
    {
      center  <- list(x = xcenter[i], y = ycenter[i])
      cluster <- LAScluster(center, width[i], height[i], buffer, LIDRRECTANGLE, ctg@data$filename[i], "noname", proj4string = ctg@proj4string)

      cluster@select <- ctg@input_options$select
      cluster@filter <- paste(cluster@filter, ctg@input_options$filter)

      return(cluster)
    })
  }
  else
  {
    bboxes = mapply(raster::extent, xcenter-width/2, xcenter+width/2, ycenter-height/2, ycenter+height/2)
    clusters = suppressWarnings(catalog_index(ctg, bboxes, LIDRRECTANGLE, buffer))
    clusters = clusters[!sapply(clusters, is.null)]
  }

  # Post process the clusters
  # =========================

  # Specific case for computation speed
  # -----------------------------------

  if (by_file & buffer == 0)
  {
    clusters <- lapply(clusters, function(x)
    {
      x@filter <- ctg@input_options$filter
      return(x)
    })
  }

  # Record the path to write the raster if requested
  # ------------------------------------------------

  if (get_output_files(ctg) != "")
  {
    clusters <- lapply(seq_along(clusters), function(i)
    {
      X         <- list()
      X$ID      <- i
      X$XCENTER <- clusters[[i]]@center$x
      X$XCENTER <- clusters[[i]]@center$y
      X$XLEFT   <- clusters[[i]]@bbox[1]
      X$XRIGHT  <- clusters[[i]]@bbox[3]
      X$YBOTTOM <- clusters[[i]]@bbox[2]
      X$YTOP    <- clusters[[i]]@bbox[4]

      if (by_file)
        X$ORIGINALFILENAME <- tools::file_path_sans_ext(basename(ctg@data$filename[i]))

      clusters[[i]]@save   <- glue::glue_data(X, get_output_files(ctg))
      return(clusters[[i]])
    })
  }

  # Plot the catalog and the clusters
  # =================================

  if(get_progress(ctg))
  {
    xrange = c(min(xmin), max(xmax))
    yrange = c(min(ymin), max(ymax))
    title  = "Pattern of clusters"
    plot.LAScatalog(ctg, mapview = FALSE, main = title, xlim = xrange, ylim = yrange)

    lapply(clusters, function(x)
    {
      graphics::rect(x@bbox[1], x@bbox[2], x@bbox[3], x@bbox[4], border = "red")

      if (x@buffer != 0)
        graphics::rect(x@bbbox[1], x@bbbox[2], x@bbbox[3], x@bbbox[4], border = "darkgreen", lty = "dotted")
    })
  }

  return(clusters)
}