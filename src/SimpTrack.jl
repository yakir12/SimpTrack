module SimpTrack

using VideoIO, OffsetArrays, ImageFiltering

export track

function get_next(guess::NTuple{2, Int}, img, window, σ, m, M)
    frame = OffsetArrays.centered(img, guess)[window]
    x = imfilter(frame, -Kernel.DoG(σ))
    _, i = findmax(x)
    _guess = guess .+ Tuple(window[i])
    return min.(max.(_guess, m), M)
end

function getwindow(object_width) 
    wr = round(Int, 1.1object_width)
    w = CartesianIndex(wr, wr)
    window = -w:w
end

function initialize(::Missing, vid, object_width)
    guess = reverse(out_frame_size(vid)) .÷ 2
    initial_window = getwindow(2object_width)
    return (guess, initial_window)
end

initialize(start_location, _, object_width) = (start_location, getwindow(object_width))

function track(file::AbstractString, start::Real, stop::Real; start_location::Union{Missing, NTuple{2, Int}} = missing, object_width::Int = 60)
    vid = openvideo(file, target_format=VideoIO.AV_PIX_FMT_GRAY8)
    img = read(vid)
    t₀ = gettime(vid)
    start += t₀
    stop += t₀
    seek(vid, start)
    σ = object_width/2.355
    guess, initial_window = initialize(start_location, vid, object_width)
    sz = reverse(out_frame_size(vid))
    coords = [get_next(guess, read(vid), initial_window, σ, 1, sz)]
    t = [gettime(vid)]
    window = getwindow(object_width)
    m = first(Tuple(last(window))) + 2
    M = sz .- m
    while !eof(vid)
        read!(vid, img)
        push!(coords, get_next(coords[end], img , window, σ, m, M))
        push!(t, gettime(vid))
        if t[end] ≥ stop
            break
        end
    end
    close(vid)
    return t .- t₀, coords
end

end # module SimpTrack
