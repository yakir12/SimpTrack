module SimpTrack

using VideoIO, OffsetArrays, ImageFiltering

export track

function get_next(guess::NTuple{2, Int}, img, window, σ)
    frame = OffsetArrays.centered(img, guess)[window]
    x = imfilter(frame, -Kernel.DoG(σ))
    _, i = findmax(x)
    guess .+ Tuple(window[i])
end

function getwindow(object_width) 
    wr = round(Int, 1.1object_width)
    w = CartesianIndex(wr, wr)
    window = -w:w
end

function track(file::AbstractString, start::Real, stop::Real; start_location::Union{Missing, NTuple{2, Int}} = missing, object_width::Int = 60)
    vid = openvideo(file, target_format=VideoIO.AV_PIX_FMT_GRAY8)
    seek(vid, start)
    guess = ismissing(start_location) ? reverse(out_frame_size(vid)) .÷ 2 : start_location
    σ = object_width/2.355
    coords = [get_next(guess, read(vid), getwindow(2object_width), σ)]
    t = [gettime(vid)]
    window = getwindow(object_width)
    for img in vid
        push!(coords, get_next(coords[end], img, window, σ))
        push!(t, gettime(vid))
        if t[end] ≥ stop
            break
        end
    end
    return t, coords
end

end # module SimpTrack
