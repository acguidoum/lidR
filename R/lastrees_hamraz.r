#' Individual tree segmentation
#'
#' The segmentation algorithm proposed by Hamraz et al. 2012 (see reference). The classification is
#' done at the point cloud level and the function returns nothing (NULL). The original point cloud
#' is updated in place with an ID for each point in a new column \code{treeID}. The user is free to
#' post-process this output the way he want.
#'
#' This function has been written by the \code{lidR} authors from the original article. We made our
#' best to implement as far as possible exactly what is written in the original paper but we
#' cannot affirm that it is this exact original algorithm.\cr\cr
#' Also it is important to notice that we have never been able to segment a single tree properly with
#' this method. The important sensitivity to minor deviation as well as the great number of difficultly
#' parametrizable imputs lead us to a method that we are not able to use ourselves.\cr\cr
#' Also, minor variations were introduced to fix some issues that were not adressed in the original paper.
#' Because the methods described in section 2.2 of the original article appear extremely sensitive to
#' many minor deviations, we introduced an optionnal additionnal step to clean the profiles used to build
#' the convex hull. When \code{filter_profiles = TRUE}, profiles that discribe a crown radius smaller than
#' \code{2*nps} (basically radius that are close to 0) are removed and the convex hull is build considering
#' the profiles that describe a crown radius comprise between the 10th and the 90th of the radiuses found.
#' This enable to remove outliers and reduce dummy segmentation but anyway we were not able to segment
#' the tree with this method.\cr\cr
#' As a conclusion this algorithm might be considered as a free and open source code provided to be
#' improved by the community. One can check and study the sources to ensure that it correspond to the
#' original paper and find potential improvement.\cr\cr
#' Also the current implementation is known to be slow.
#'
#' @param las A LAS object
#' @param nps numeric. Nominal point spacing (see reference page 533  section 2)
#' @param th numeric. Minimal height. Point below this threshold are not condisered for the segmentation (see reference page 534 section 2)
#' @param MDCW numeric. Minimum detectable crown width (page 534 section 2)
#' @param epsilon numeric. Small deviation from vertical (page 535 section 2.2.2)
#' @param CLc numeric. Crown ratio of a narrow cone-shaped crown (page 535 equation 3)
#' @param Oc numeric. Crown radius reduction due to the overlap assuming the narrow cone-shaped tree is situated in a dense stand (page 535 equation 3)
#' @param CLs numeric. Crown ratio of a sphere-shaped crown (page 535 equation 4)
#' @param Os numeric. Crown radius reduction due to the overlap within a dense stand for the sphere-shaped tree (page 535 equation 4)
#' @param R numeric Maximum horizontal distance of vertical profiles (page 535 sectioh 2.1). Any value greater
#' than a crown is good because this parameter does not affect the result. However, it greatly affects the
#' computation speed. The lower the value, the faster the method.
#' @param gap_sensitivity integer. In the original article, page 535 section 2.2.1, gaps are detected
#' using six times the interquartile range of square root distance between consecutive points. This
#' paramter control this value. Default is 6.
#' @param filter_profiles logical. This is an addition to the original method to filter dummy profiles
#' (see details)
#' @param ... Supplementary options. Currently \code{field} is supported to change the default name of
#' the new column.
#'
#' @return
#' Nothing (NULL). The original point cloud is updated by reference. The original point cloud has a
#' new column named 'treeID' containing an ID for each point that refer to a segmented tree.
#'
#' @export
#' @references
#' Hamraz, H., Contreras, M. A., & Zhang, J. (2016). A robust approach for tree segmentation in deciduous
#' forests using small-footprint airborne LiDAR data. International Journal of Applied Earth Observation
#' and Geoinformation, 52, 532–541. https://doi.org/10.1016/j.cageo.2017.02.017
#' @examples
#' \dontrun{
#' LASfile <- system.file("extdata", "MixedConifer.laz", package="lidR")
#' las = readLAS(LASfile, select = "xyz", filter = "-drop_z_below 0")
#' col =  pastel.colors(200)
#'
#' lastrees_hamraz(las)
#'
#' plot(las, color = "treeID", colorPalette = pastel.colors(200))
#'}
#' @family tree_segmentation
lastrees_hamraz = function(las, nps = 0.25, th = 5, MDCW = 1.5, epsilon = 5, CLc = 0.8, Oc = 2/3, CLs = 0.7, Os = 1/3, gap_sensitivity = 6L, R = 15.24, filter_profiles = TRUE, ...)
{
  assertive::assert_is_a_number(nps)
  assertive::assert_all_are_positive(nps)
  assertive::assert_is_a_number(th)
  assertive::assert_all_are_positive(th)
  assertive::assert_is_a_number(MDCW)
  assertive::assert_all_are_positive(MDCW)
  assertive::assert_is_a_number(epsilon)
  assertive::assert_all_are_positive(epsilon)
  assertive::assert_is_a_number(CLc)
  assertive::assert_all_are_positive(CLc)
  assertive::assert_is_a_number(Oc)
  assertive::assert_all_are_positive(Oc)
  assertive::assert_is_a_number(CLs)
  assertive::assert_all_are_positive(CLs)
  assertive::assert_is_a_number(Os)
  assertive::assert_all_are_positive(Os)
  assertive::assert_is_a_number(gap_sensitivity)
  assertive::assert_all_are_positive(gap_sensitivity)
  assertive::assert_is_a_number(R)
  assertive::assert_all_are_positive(R)
  assertive::assert_is_a_bool(filter_profiles)

  . <- X <- Y <- Z <- NULL

  # Preprocess : LSP + remove low point + smooth
  LSP = LAS(las@data[, .(X,Y,Z)], las@header)
  LSP = lasfiltersurfacepoints(LSP, nps)    # page 533
  LSP = lasfilter(LSP, Z > th)              # page 534
  lassmooth(LSP, 3*nps, "gaussian", "square", sigma = nps)

  # ID initalization
  idTree = 0L
  treeID = rep(NA_integer_, nrow(las@data))

  # Progress estimation and stop criterion
  npts = nrow(LSP@data)
  npoints = nrow(LSP@data)
  pbar =  utils::txtProgressBar(0, npoints)

  while (npts != 0)
  {
    utils::setTxtProgressBar(pbar, npoints - npts)

    # (1) Locate the global maximum GMX (page 534)

    i = which.max(LSP@data$Z)
    GMX = LSP@data[i]
    GMX$i = i

    disc = lasclipCircle(LSP, GMX$X, GMX$Y, R)            # Extract a disc around GMX
    disc@data[, R := sqrt((X-GMX$X)^2 + (Y-GMX$Y)^2)]     # Compute cylindrical cordinates

    # (2-4) Find the convex hull according to Hamraz rules
    l = C_hamraz_segmentation(disc, nps, gap_sensitivity, MDCW, epsilon, CLc, CLs, Oc, Os, R)
    p = l$polygon
    data.table::setDT(p)

    #  Filter the convex hull and rebuild a new clean one
    if (filter_profiles)
    {
      p = p[p$R > 2 * nps]                          # Keep the profile over 1.5 m
      q = stats::quantile(p$R, probs = c(0.1, 0.9)) # Keep the profile within the 10 and 90th percentile of lenghts
      p = p[R < q[2] & R > q[1]]
    }

    area = 0
    if (nrow(p) > 3)
    {
      ch = convex_hull(p$X, p$Y)
      area = polygon_area(ch$x, ch$y)
    }


    # plot(disc@data$X, disc@data$Y, col = lidR:::set.colors(disc@data$Z, height.colors(50)), asp = 1)

    # x = numeric(64)
    # y = numeric(64)
    # a = numeric(64)
    # for(i in 1:64)
    # {
    #   x[i] = GMX$X + l$profile[[i]]$extremityPoint[5] * cos(l$profile[[i]]$angle*pi/180)
    #   y[i] = GMX$Y + l$profile[[i]]$extremityPoint[5] * sin(l$profile[[i]]$angle*pi/180)
    #   a[i] = l$profile[[i]]$angle
    #   points(l$profile[[i]]$extremityPoint[1], l$profile[[i]]$extremityPoint[2], col = "red", pch = 19)
    # }

    #lines(l$polygon[,1 ], l$polygon[,2], col = "red")
    #lines(p$x, p$y)

    # (5) cluster all LSPs encompassed within the convex hull and assign them as the current tallest tree crown
    in_p = logical(nrow(LSP@data))

    if(area == 0)
    {
      # The current point GMX will be removed (otherwise, we get stucked in a infinite loop).
      in_p[GMX$i] = TRUE
    }
    # else this is a normal case
    else
    {
      # Find the points that belong in the convex hull
      in_p = C_points_in_polygon(ch$x, ch$y, LSP@data$X, LSP@data$Y)

      # If no point found within this polygon only GMX will be remove
      if (sum(in_p) == 0) in_p[GMX$i] = TRUE
    }

    # extract the tree as a data.table
    tree = LSP@data[in_p]

    # extract the rest of the forest as a LAS
    LSP = suppressWarnings(lasfilter(LSP, !in_p))

    #plot(LSP@data$X, LSP@data$Y, col = lidR:::set.colors(LSP@data$Z, height.colors(50)), asp = 1)

    # There are still points to classify
    if (!is.null(LSP))
      npts = nrow(LSP@data)
    else
      npts = 0

    # Finally attribute an ID to each point of the original dataset (Hamraz considers only the LSP
    # but we classify the whole point cloud)
    if (area > pi*(MDCW/2)^2)
    {
        idTree <- idTree + 1

        las_in_p = C_points_in_polygon(ch$x, ch$y, las@data$X, las@data$Y)

        # a new ID is attributed only to points that don't already have an ID (dominant has precedence)
        update = las_in_p & is.na(treeID)
        treeID[update] = idTree
    }

    #plot(las@data$X, las@data$Y, col = treeID, asp = 1)
  }

  field = "treeID"
  p = list(...)
  if(!is.null(p$field))
    field = p$field

  lasaddextrabytes(las, treeID, field, "A unique ID for each tree")

  return(invisible(las))
}

