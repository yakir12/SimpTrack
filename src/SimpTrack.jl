module SimpTrack

using LinearAlgebra
using VideoIO, OffsetArrays, ImageFiltering, PaddedViews, StatsBase

# export track

function getnext(guess, img, window, kernel, sz)
    frame = OffsetArrays.centered(img, guess)[window]
    x = imfilter(frame, kernel)
    _, i = findmax(x)
    guess = guess .+ Tuple(window[i])
    return min.(max.(guess, (1, 1)), sz)
end

function getwindow(window_size)
    radii = window_size .÷ 2
    wr = CartesianIndex(radii)
    window = -wr:wr
    return radii, window
end

initiate(vid, _, start_xy) = (reverse(out_frame_size(vid)), read(vid), reverse(start_xy))

function initiate(vid, kernel, ::Missing)
    sz = reverse(out_frame_size(vid))
    guess = sz .÷ 2
    _, initial_window = getwindow(sz .÷ 2)
    img = read(vid)
    start_ij = getnext(guess, img, initial_window, kernel, sz)

    return sz, img, start_ij
end

function guess_window_size(object_width)
    h = round(Int, 1.5object_width)
    return (h, h)
end

"""
`object_width` is the full width of the traget (diameter, not radius). It is used as the FWHM of the center gaussian in the DoG filter.
`start_xy` is (x, y) where x and y are the horizontal and vertical pixel-distances between the left-top corner of the video-frame and the center of the target at `start`.
`window_size` is (w, h) where w and h are the full width and height of the window around the target that the algorithm will look for the next location. This should be larger than the `object_width` and relate to how fast the taget moves between subsequent frames.
"""
function track(file::AbstractString; 
        start::Real = 0,
        stop::Real = VideoIO.get_duration(file),
        object_width::Int = 25,
        start_xy::Union{Missing, NTuple{2, Int}} = missing,
        window_size::NTuple{2, Int} = guess_window_size(object_width)
    )

    openvideo(vid -> _track(vid, start, stop, object_width, start_xy, window_size), file, target_format=VideoIO.AV_PIX_FMT_GRAY8)
end

function _track(vid, start, stop, object_width, start_xy, window_size)
    read(vid) # needed to get the right time offset t₀
    t₀ = gettime(vid)
    start += t₀
    stop += t₀
    seek(vid, start)

    σ = object_width/2.355
    kernel = -Kernel.DoG(σ)

    sz, img, start_ij = initiate(vid, kernel, start_xy)

    coords = [start_ij]
    ts = [gettime(vid)]
    wr, window = getwindow(reverse(window_size))
    indices = UnitRange.(1 .- wr, sz .+ wr)
    fillvalue = mode(img)
    pimg = PaddedView(fillvalue, img, indices)

    while !eof(vid)
        read!(vid, pimg.data)
        guess = getnext(coords[end], pimg , window, kernel, sz)
        push!(coords, guess)
        push!(ts, gettime(vid))
        if ts[end] ≥ stop
            break
        end
    end

    return ts .- t₀, reverse.(coords)
end


end # module SimpTrack
