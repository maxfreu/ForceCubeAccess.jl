function seriesrepresentation(fc::ForceCube; times=alltimes(fc))
    slices = [TimeSlice(extract_timeslice(fc, t; crop=false), t, fc.def) for t in times]

    # TODO: do sth here to pad TimeSlices with non-matching size to the size of the others
    # so that they all cover the same extent

    return RasterSeries(slices, (Ti(times),), Tuple{}())
end