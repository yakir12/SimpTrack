# module SimpTrack

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

function guess_start_location(file, object_width)
    σ = object_width/2.355
    kernel = -Kernel.DoG(σ)
    vid = openvideo(file, target_format=VideoIO.AV_PIX_FMT_GRAY8)
    sz = reverse(out_frame_size(vid))
    start_location = sz .÷ 2
    _, initial_window = getwindow(sz .÷ 2)
    img = read(vid)
    close(vid)
    guess = getnext(start_location, img, initial_window, kernel, sz)
    reverse(guess)
end

"""
`object_width` is the full width of the traget (diameter, not radius). It is used as the FWHM of the center gaussian in the DoG filter.
`start_location` is (x, y) where x and y are the horizontal and vertical pixel-distances between the left-top corner of the video-frame and the center of the target at `start`.
`window_size` is (w, h) where w and h are the full width and height of the window around the target that the algorithm will look for the next location. This should be larger than the `object_width` and relate to how fast the taget moves between subsequent frames.
"""
function track(file::AbstractString; 
        start::Real = 0,
        stop::Real = VideoIO.get_duration(file),
        object_width::Int = 25,
        start_location::NTuple{2, Int} = guess_start_location(file, object_width),
        window_size::NTuple{2, Int} = (2object_width, 2object_width))

    vid = openvideo(file, target_format=VideoIO.AV_PIX_FMT_GRAY8)
    img = read(vid)
    t₀ = gettime(vid)
    start += t₀
    stop += t₀
    seek(vid, start)

    σ = object_width/2.355
    kernel = -Kernel.DoG(σ)

    start_location = reverse(start_location)
    sz = reverse(out_frame_size(vid))

    coords = [start_location]
    ts = [gettime(vid)]
    wr, window = getwindow(reverse(window_size))
    indices = UnitRange.(1 .- wr, sz .+ wr)
    fillvalue = mode(img)
    pimg = PaddedView(fillvalue, img, indices)

    ts, corrds = _track(vid, stop, coords, ts, pimg, window, kernel, sz) 

    return ts .- t₀, reverse.(coords)
end


function _track(vid::VideoIO.VideoReader, stop, coords, ts, pimg, window, kernel, sz)

    while !eof(vid)
        read!(vid, pimg.data)
        guess = getnext(coords[end], pimg , window, kernel, sz)
        push!(coords, guess)
        push!(ts, gettime(vid))
        if ts[end] ≥ stop
            break
        end
    end
    close(vid)

    return ts, coords
end





sz = (100, 150)
start_location = sz .÷ 2 .+ (-25, -10)
# start_location = (10, 20)
object_width = 10
window_size = (20, 20)
using GLMakie
fig = Figure(size = sz, figure_padding = 0)
ax = Axis(fig[1,1], limits = ((0, sz[1]), (0, sz[2])), yreversed = true)
xy = Observable(Point2f(start_location))
poly!(ax, @lift(Circle($xy, object_width/2)), color = :black)
hidespines!(ax)
hidedecorations!(ax)
data = Point2f[]
push!(data, xy[])
file = "example.mp4"
framerate = 24
s = 4
n = s*framerate
record(fig, file, 1:n; framerate) do i
    α = asin(i/n)
    sc = sincos(α)
    l = 0.1rand()*minimum(window_size ./ 2 ./ sc)
    xy[] += Point2f(reverse(sc))*l
    push!(data, xy[])
end


t, xy = track(file; object_width)
fig = Figure()
ax = Axis(fig[1,1], limits = ((0, sz[1]), (0, sz[2])), aspect = DataAspect())
lines!(ax, data, color = :blue)
lines!(ax, xy, color = :red)
display(fig)

mean(LinearAlgebra.norm_sqr, data .- Point2f.(xy))
# lines!([(sz[1], 0) .- reverse(x) for x in xy])


# end # module SimpTrack
