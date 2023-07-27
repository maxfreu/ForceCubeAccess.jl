function seriesrepresentation(fc::ForceCube)
    times = alltimes(fc)
    slices = [TimeSlice(extract_timeslice(fc, t), t, fc.def) for t in times]
    return RasterSeries(slices, (times,), Tuple{}())
end