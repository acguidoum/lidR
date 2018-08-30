#' Individual tree segmentation
#'
#' Individual tree segmentation using Silva et al. (2016) algorithm (see reference).
#' This is a simple method based on local maxima + voronoi tesselation. This algorithm is implemented
#' in the package \code{rLiDAR}. This version is \emph{not} the version from \code{rLiDAR}. It is a
#' code written from scratch by the lidR author from the original paper and is considerably
#' (between 250 and 1000 times) faster.
#'
#' @param las An object of the class \code{LAS}. If missing \code{extra} is turned to \code{TRUE}
#' automatically.
#' @param extra logical. By default the function classifies the original point cloud by reference
#' and return nothing (NULL) i.e. the original point cloud is automatically updated in place. If
#' \code{extra = TRUE} an additional \code{RasterLayer} used internally can be returned.
#' @template param-chm-lastrees
#' @template param-treetops
#' @param max_cr_factor numeric. Maximum value of a crown diameter given as a proportion of the
#' tree height. Default is 0.6,  meaning 60\% of the tree height.
#' @param exclusion numeric. For each tree, pixels with an elevation lower than \code{exclusion}
#' multiplied by the tree height will be removed. Thus, this number belongs between 0 and 1.
#' @param field character. If the \code{SpatialPointsDataFrame} contains an attribute with the ID for
#' each tree, the name of this column. This way, original IDs will be preserved. If there is no scuh data
#' trees will be numbered sequentially.
#'
#' @return Nothing (NULL), the point cloud is updated by reference. The original point cloud
#' has a new column named \code{treeID} containing an ID for each point that refer to a segmented tree.
#' If \code{extra = TRUE} the function returns a \code{RasterLayer} used internally.
#'
#' @examples
#' LASfile <- system.file("extdata", "MixedConifer.laz", package="lidR")
#' las = readLAS(LASfile, select = "xyz", filter = "-drop_z_below 0")
#' col = pastel.colors(200)
#'
#' chm = grid_canopy(las, "p2r", res = 0.5, subcircle = 0.3)
#' kernel = matrix(1,3,3)
#' chm = raster::focal(chm, w = kernel, fun = mean, na.rm = TRUE)
#'
#' ttops = tree_detection(chm, "lmf", 4, 2)
#' lastrees_silva(las, chm, ttops)
#' plot(las, color = "treeID", colorPalette = col)
#'
#' @references
#' Silva, C. A., Hudak, A. T., Vierling, L. A., Loudermilk, E. L., O’Brien, J. J., Hiers,
#' J. K., Khosravipour, A. (2016). Imputation of Individual Longleaf Pine (Pinus palustris Mill.)
#' Tree Attributes from Field and LiDAR Data. Canadian Journal of Remote Sensing, 42(5), 554–573.
#' https://doi.org/10.1080/07038992.2016.1196582.
#' @export
#' @family  tree_segmentation
lastrees_silva = function(las, chm, treetops, max_cr_factor = 0.6, exclusion = 0.3, extra = FALSE, field = "treeID")
{
  stopifnotlas(las)
  assertive::assert_is_all_of(chm, "RasterLayer")
  assertive::assert_is_all_of(treetops, "SpatialPointsDataFrame")
  assertive::assert_is_a_number(max_cr_factor)
  assertive::assert_is_a_number(exclusion)
  assertive::assert_is_a_bool(extra)
  assertive::assert_all_are_in_open_range(max_cr_factor, 0, 1)
  assertive::assert_all_are_in_open_range(exclusion, 0, 1)

  stopif_forbidden_name(field)

  . <- R <- X <- Y <- Z <- id <- d <- hmax <- NULL

  X = match_chm_and_seeds(chm, treetops, field)
  cells = X$cells
  ids = X$ids

  chmdt = data.table::setDT(raster::as.data.frame(chm, xy = TRUE, na.rm = T))
  data.table::setnames(chmdt, names(chmdt), c("X", "Y", "Z"))

  # Voronoi tesselation is nothing else than the nearest neigbour
  u = C_knn(treetops@coords[,1], treetops@coords[,2], chmdt$X, chmdt$Y, 1L)
  chmdt[, id := u$nn.idx[,1]]
  chmdt[, id := ids[id]]
  chmdt[, d := u$nn.dist[,1]]

  chmdt[, hmax := max(Z), by = id]
  chmdt = chmdt[Z >= exclusion*hmax & d <= max_cr_factor*hmax, .(X,Y, id)]
  as.lasmetrics(chmdt, raster::res(chm)[1])
  crown = as.raster.lasmetrics(chmdt)

  if(!missing(las))
  {
    lasclassify(las, crown, field)
    lasaddextrabytes(las, name = field, desc = "An ID for each segmented tree")
  }

  if (!extra & !missing(las))
    return(invisible(las))
  else
    return(crown)
}