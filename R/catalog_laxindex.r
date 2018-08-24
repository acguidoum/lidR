catalog_laxindex = function(ctg)
{
  stopifnot(is(ctg, "LAScatalog"))

  by_file(ctg) <- TRUE
  buffer(ctg)  <- 0

  create_lax_file = function(cluster)
  {
    rlas::writelax(cluster@files)
    return(0)
  }

  catalog_apply2(ctg, create_lax_file, need_buffer = FALSE, check_alignement = FALSE, drop_null = FALSE)
  return(invisible())
}