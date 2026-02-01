# let 
#     ## ------------------------------------------------------------
#     # save/load data
#     Proj = Project0(tempdir())

#     try
#         rm(datdir(Proj); force = true, recursive = true)
        
#         @info("save/load data", Proj)
#         mkdir = true
#         for (sfun, lfun) in [
#                 (sdat, ldat),
#                 (sprocdat, lprocdat), 
#                 (srawdat, lrawdat),
#                 (scachedat, lcachedat),
#             ]

#             dat0 = rand(10, 10)

#             for fargs in [
#                         ("test_file", ".jls"),
#                         ("test_file", (;h = hash(dat0)), ".jls"),
#                         (["subdir"], "test_file", (;h = hash(dat0)), ".jls"),
#                     ]

#                 cfile1, _ = sfun(Proj, dat0, fargs...; mkdir)
#                 @show cfile1
#                 @test isfile(cfile1)
#                 _, dat1 = lfun(Proj, fargs...)
#                 @test all(dat0 .== dat1)
#                 _, dat1 = lfun(Proj, cfile1)
#                 @test all(dat0 .== dat1)
#                 cfile2, _ = sfun(Proj, dat0, basename(cfile1); mkdir)
#                 @test basename(cfile1) == basename(cfile2)
#                 _, dat1 = lfun(Proj, cfile2)
#                 @test all(dat0 .== dat1)
#             end
#         end # for (sfun, lfun)

#         ## ------------------------------------------------------------
#         # save/load cache

#         dat0 = rand(10, 10)
        
#         cid = (:TEST, :CACHE, hash(dat0))
#         cfile, _ = scachedat(Proj, dat0, cid)
#         @show cfile
#         @test isfile(cfile)
#         _, dat1 = lcachedat(Proj, cid)
#         @test all(dat0 .== dat1)
        
#     finally
#         rm(datdir(Proj); force = true, recursive = true)
#     end
# end