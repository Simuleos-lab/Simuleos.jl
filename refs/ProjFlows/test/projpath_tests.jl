let
    P = Project0(ProjFlows)
    globproj!(P)
    
    N = 10
    # fn = projpath(["dev"], "comment", (N,), ".jls")
    fn = projpath("/abs/path")
    @time fn == "/abs/path"
    fn2 = projpath("abs/path")
    @time fn2 != "/abs/path"
    fn3 = projpath(P, ["abs", "path"])
    @time fn3 == fn2
end