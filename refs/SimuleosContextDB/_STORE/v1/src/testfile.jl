function approximatePi(nsamples)

    successes = 0
    D = Uniform(-1,1) # assert !changed
    
    for it in 1:nsamples
        x0 = rand(D)
        x1 = rand(D)
        success = x0^2 + x1^2 < 1
        success || continue
        # success territory
        successes += 1
    end

    # pi found
    pi_ = (4 * successes) / nsamples

    return pi_

end