// Code is from Lohikar and aurora station

// Builds a list of turfs belonging to an area in a predictable order.
// Two areas of the same size should have directly comparable ordered turf lists.
// If ignore_type has a value, that turf will be excluded from the list.
// Excluded turfs are represented by null values in the list to maintain order.
/area/proc/build_ordered_turf_list(ignore_type)
	. = list()

	// Find the maximums and minimums of the area.
	var/xmax = -1
	var/ymax = -1
	var/zmax = -1
	var/xmin = INFINITY
	var/ymin = INFINITY
	var/zmin = INFINITY

	for (var/turf/T in src)
		if (T.x > xmax)
			xmax = T.x

		if (T.x < xmin)
			xmin = T.x

		if (T.y > ymax)
			ymax = T.y

		if (T.y < ymin)
			ymin = T.y

		if (T.z > zmax)
			zmax = T.z

		if (T.z < zmin)
			zmin = T.z

	//log_debug("build_ordered_turf_list([DEBUG_REF(src)]): xmax=[xmax],xmin=[xmin],ymax=[ymax],ymin=[ymin],z=[z]")

	// These are split out to make diagnosing which one failed easier, the overhead is trivial given that most of the cost is in the loop above and below.
	ASSERT(xmax > 0)
	ASSERT(xmin < INFINITY)
	ASSERT(ymax > 0)
	ASSERT(ymin < INFINITY)
	ASSERT(zmax > 0)
	ASSERT(zmax < INFINITY)

	// Now use our information to build an *ordered* list of turfs.
	for (var/z = zmin to zmax)
		for (var/x = xmin to xmax)
			for (var/y = ymin to ymax)
				var/turf/T = locate(x, y, z)
				if (T.loc != src || T.type == ignore_type)
					// Not ours or ignored type, we don't give a crap.
					// Add a null to keep the list a predictable size.
					. += null
				else
					// Turf matches, add it.
					. += T

// Moves the contents of this area to A. If turf_to_leave is defined, that type will be excluded from the area.
/area/proc/move_contents_to(area/A, turf_to_leave = null)
	var/list/source_turfs = src.build_ordered_turf_list(turf_to_leave)
	var/list/target_turfs = A.build_ordered_turf_list()

	ASSERT(source_turfs.len == target_turfs.len)

	for (var/i = 1 to source_turfs.len)
		var/turf/ST = source_turfs[i]
		if (!ST)	// Excluded turfs are null to keep the list ordered.
			continue

		var/turf/TT = ST.copy_turf(target_turfs[i])

		for (var/thing in ST)
			var/atom/movable/AM = thing
			AM.forceMove(TT)
			//AM.shuttle_move(TT)

		ST.ChangeTurf(A.base_turf)

		TT.update_icon()
//		TT.update_above()

// Called when a movable area wants to move this object.
/atom/movable/proc/shuttle_move(turf/loc)
	forceMove(loc)

// In theory, this copies the contents of the area to another, and returns a list containing every new object it created.
// It's not tested because the holodeck doesn't work yet.
/area/proc/copy_contents_to(area/A, plating_required = FALSE)
	var/list/source_turfs = src.build_ordered_turf_list()
	var/list/target_turfs = A.build_ordered_turf_list()

	. = list()

	ASSERT(source_turfs.len == target_turfs.len)

	var/baseturf
	if (plating_required)
		baseturf = A.base_turf
		if (!baseturf)
			var/turf/T
			for (var/idex = 1; T == null; idex++)
				if (idex > target_turfs.len)
					CRASH("Empty target_turfs list!")

				T = target_turfs[idex]

			baseturf = A.base_turf

	for (var/i = 1 to source_turfs.len)
		var/turf/ST = source_turfs[i]
		var/turf/TTi = target_turfs[i]
		if (!ST || (plating_required && TTi.type == baseturf))	// Excluded turfs are null to keep the list ordered.
			continue

		var/turf/TT
		if (istype(ST, /turf/simulated))
			var/turf/simulated/SST = ST
			TT = SST.copy_turf(TTi, ignore_air = TRUE)
		else
			TT = ST.copy_turf(TTi)

		for (var/thing in ST)
			var/atom/movable/AM = thing
			var/atom/movable/copy = DuplicateObject(AM, 1)
			copy.forceMove(TT)
			. += copy

		//air_master.mark_for_update(TT)


// Copies this turf to other, overwriting it.
// Returns a ref to the other turf post-change.
/turf/proc/copy_turf(turf/other)
    if (other.type != type)
        . = other.ChangeTurf(type)
    else
        . = other

    if (dir != other.dir)
        other.set_dir(dir)

    other.icon = icon
    other.icon_state = icon_state
    other.underlays = underlays.Copy()
/*
    if (our_overlays)
        other.our_overlays = our_overlays

    if (priority_overlays)
        other.priority_overlays = priority_overlays
*/
    other.overlays = overlays.Copy()
/*
/turf/simulated/copy_turf(turf/simulated/other, ignore_air = FALSE)
    . = ..()

    if (ignore_air || !istype(other))
        return

    if (air)
        if (!other.air)
            other.make_air()
        other.air.copy_from(air)

    air_master.mark_for_update(other)
    //other.queue_icon_update()
*/