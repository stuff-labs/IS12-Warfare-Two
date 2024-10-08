/obj/item/ammo_casing
	name = "bullet casing"
	desc = "A bullet casing."
	icon = 'icons/obj/ammo.dmi'
	icon_state = "s-casing"
	randpixel = 10
	obj_flags = OBJ_FLAG_CONDUCTIBLE
	slot_flags = SLOT_BELT | SLOT_EARS
	throwforce = 1
	w_class = ITEM_SIZE_TINY

	var/leaves_residue = 1
	var/caliber = ""					//Which kind of guns it can be loaded into
	var/projectile_type					//The bullet type to create when New() is called
	var/obj/item/projectile/BB = null	//The loaded bullet - make it so that the projectiles are created only when needed?
	var/spent_icon = "s-casing-spent"
	var/ammo_stack = null 				//Put the path of the ammo stack you'd like to create here. It creates an ammo stack when you combine two of the same ammo type.
	drop_sound = 'sound/items/handle/casing_drop.ogg'


/obj/item/ammo_casing/New()
	..()
	if(ispath(projectile_type))
		BB = new projectile_type(src)

//removes the projectile from the ammo casing
/obj/item/ammo_casing/proc/expend()
	. = BB
	BB = null
	var/matrix/M = matrix()
	M.Turn(rand(180))
	src.transform = M //spin spent casings

	// Aurora forensics port, gunpowder residue.
	if(leaves_residue)
		leave_residue()
		pixel_x = rand(-randpixel, randpixel)
		pixel_y = rand(-randpixel, randpixel)

	update_icon()
	mouse_opacity = 0

/obj/item/ammo_casing/proc/leave_residue()
	var/mob/living/carbon/human/H
	if(ishuman(loc))
		H = loc //in a human, somehow
	else if(loc && ishuman(loc.loc))
		H = loc.loc //more likely, we're in a gun being held by a human

	if(H)
		if(H.gloves && (H.l_hand == loc || H.r_hand == loc))
			var/obj/item/clothing/G = H.gloves
			G.gunshot_residue = caliber
		else
			H.gunshot_residue = caliber



/obj/item/ammo_casing/attackby(obj/item/W as obj, mob/user as mob)
	if(isScrewdriver(W))
		if(!BB)
			to_chat(user, "<span class='notice'>There is no bullet in the casing to inscribe anything into.</span>")
			return

		var/tmp_label = ""
		var/label_text = sanitizeSafe(input(user, "Inscribe some text into \the [initial(BB.name)]","Inscription",tmp_label), MAX_NAME_LEN)
		if(length(label_text) > 20)
			to_chat(user, "<span class='warning'>The inscription can be at most 20 characters long.</span>")
		else if(!label_text)
			to_chat(user, "<span class='notice'>You scratch the inscription off of [initial(BB)].</span>")
			BB.SetName(initial(BB.name))
		else
			to_chat(user, "<span class='notice'>You inscribe \"[label_text]\" into \the [initial(BB.name)].</span>")
			BB.SetName("[initial(BB.name)] (\"[label_text]\")")

	if(istype(W, /obj/item/ammo_casing))
		if(src.type == W.type)
			var/obj/item/ammo_casing/A = W
			if(A.BB && src.BB && ammo_stack)
				var/obj/item/ammo_magazine/handful/H = new ammo_stack(src.loc)
				H.update_icon()
				qdel(src)
				qdel(A)
				user.put_in_hands(H)

	if(istype(W, /obj/item/ammo_magazine))
		var/obj/item/ammo_magazine/A = W
		if(caliber == A.caliber && src.BB)
			if(A.stored_ammo.len >= A.max_ammo)
				to_chat(user, "<span class='warning'>[A] is full!</span>")
				return
			else
				if(src.loc == user)
					user.remove_from_mob(src)
				forceMove(A)
				A.stored_ammo.Add(src)
				A.update_icon()
				//user.visible_message("<span class='notice'>\The [user] adds \a [src] to [A].</span>", "<span class='notice'>You add \a [src] to [A].</span>")

	else ..()

/obj/item/ammo_casing/update_icon()
	if(spent_icon && !BB)
		icon_state = spent_icon

/obj/item/ammo_casing/examine(mob/user)
	. = ..()
	if (!BB)
		to_chat(user, "This one is spent.")

//Gun loading types
#define SINGLE_CASING 	1	//The gun only accepts ammo_casings. ammo_magazines should never have this as their mag_type.
#define SPEEDLOADER 	2	//Transfers casings from the mag to the gun when used.
#define SINGLE_LOAD		3	//It only loads one at a time.
#define MAGAZINE 		4	//The magazine item itself goes inside the gun

//An item that holds casings and can be used to put them inside guns
/obj/item/ammo_magazine
	name = "magazine"
	desc = "A magazine for some kind of gun."
	icon_state = "357"
	icon = 'icons/obj/ammo.dmi'
	obj_flags = OBJ_FLAG_CONDUCTIBLE
	slot_flags = SLOT_BELT
	item_state = "syringe_kit"
	matter = list(DEFAULT_WALL_MATERIAL = 500)
	throwforce = 5
	w_class = ITEM_SIZE_SMALL
	throw_speed = 4
	throw_range = 10
	bag_place_sound = 'sound/items/handle/mag_pouch_in.ogg'
	drop_sound = 'sound/items/handle/magdrop.ogg'
	bag_pickup_sound = 'sound/items/handle/weap_mag_pullout.ogg'

	var/list/stored_ammo = list()
	var/mag_type = SPEEDLOADER //ammo_magazines can only be used with compatible guns. This is not a bitflag, the load_method var on guns is.
	var/caliber = "357"
	var/max_ammo = 7
	var/load_inddividually = FALSE

	var/ammo_type = /obj/item/ammo_casing //ammo type that is initially loaded
	var/initial_ammo = null

	var/multiple_sprites = 0
	//because BYOND doesn't support numbers as keys in associative lists
	var/list/icon_keys = list()		//keys
	var/list/ammo_states = list()	//values

/obj/item/ammo_magazine/box
	w_class = ITEM_SIZE_NORMAL

/obj/item/ammo_magazine/New()
	..()
	if(multiple_sprites)
		initialize_magazine_icondata(src)

	if(isnull(initial_ammo))
		initial_ammo = max_ammo

	if(initial_ammo)
		for(var/i in 1 to initial_ammo)
			stored_ammo += new ammo_type(src)
	update_icon()

/obj/item/ammo_magazine/attackby(obj/item/W as obj, mob/user as mob)
	if(istype(W, /obj/item/ammo_casing))
		var/obj/item/ammo_casing/C = W
		if(C.caliber != caliber)
			to_chat(user, "<span class='warning'>[C] does not fit into [src].</span>")
			return
		if(stored_ammo.len >= max_ammo)
			to_chat(user, "<span class='warning'>[src] is full!</span>")
			return
		user.remove_from_mob(C)
		C.forceMove(src)
		stored_ammo.Add(C)
		update_icon()

	if(istype(W, /obj/item/ammo_magazine))
		var/obj/item/ammo_magazine/A = W
		if(caliber == A.caliber)
			if(!A.stored_ammo.len)
				to_chat(user, "<span class='notice'>[A] is empty!</span>")
			else if(stored_ammo.len >= max_ammo)
				to_chat(user, "<span class='warning'>[src] is full!</span>")
				return
			else
				var/obj/item/ammo_casing/C = A.stored_ammo[A.stored_ammo.len]
				A.stored_ammo-=C
				C.forceMove(src)
				stored_ammo.Add(C)
				update_icon()
				A.update_icon()
				//user.visible_message("<span class='notice'>\The [user] adds \a [C] to [src].</span>", "<span class='notice'>You add \a [C] to [src].</span>")


	else ..()

/obj/item/ammo_magazine/attack_self(mob/user)
	if(!stored_ammo.len)
		to_chat(user, "<span class='notice'>[src] is empty!</span>")
		return
	to_chat(user, "There [(stored_ammo.len == 1)? "is" : "are"] [stored_ammo.len] round\s left!")


/obj/item/ammo_magazine/attack_hand(mob/user)
	if(user.get_inactive_hand() == src)
		if(!stored_ammo.len)
			to_chat(user, "<span class='notice'>[src] is already empty!</span>")
		else
			var/obj/item/ammo_casing/C = stored_ammo[stored_ammo.len]
			stored_ammo-=C
			user.put_in_hands(C)
			user.visible_message("\The [user] removes \a [C] from [src].", "<span class='notice'>You remove \a [C] from [src].</span>")
			update_icon()
	else
		..()
		return

/obj/item/ammo_magazine/update_icon()
	if(multiple_sprites)
		//find the lowest key greater than or equal to stored_ammo.len
		var/new_state = null
		for(var/idx in 1 to icon_keys.len)
			var/ammo_count = icon_keys[idx]
			if (ammo_count >= stored_ammo.len)
				new_state = ammo_states[idx]
				break
		icon_state = (new_state)? new_state : initial(icon_state)

/obj/item/ammo_magazine/examine(mob/user)
	. = ..()
	to_chat(user, "There [(stored_ammo.len == 1)? "is" : "are"] [stored_ammo.len] round\s left!")

/obj/item/ammo_casing/throw_at(var/atom/target) //The little bouncing animation.
	..()
	if(isturf(target))

		var/Xplusbound = 34
		var/Yplusbound = 34

		var/Xminusbound = -34
		var/Yminusbound = -34

//Add diagonals if it winds up mattering.
		if(isturf(get_step(src, NORTH)))
			Yplusbound = 15
		if(isturf(get_step(src, EAST)))
			Xplusbound = 15
		if(isturf(get_step(src, SOUTH)))
			Yminusbound = -15
		if(isturf(get_step(src, WEST)))
			Xminusbound = -15
		animate(src, pixel_x = rand(Xminusbound,Xplusbound), pixel_y = rand(Yminusbound,Yplusbound), time = 5, easing = BOUNCE_EASING, flags = ANIMATION_PARALLEL )

//magazine icon state caching
/var/global/list/magazine_icondata_keys = list()
/var/global/list/magazine_icondata_states = list()

/proc/initialize_magazine_icondata(var/obj/item/ammo_magazine/M)
	var/typestr = "[M.type]"
	if(!(typestr in magazine_icondata_keys) || !(typestr in magazine_icondata_states))
		magazine_icondata_cache_add(M)

	M.icon_keys = magazine_icondata_keys[typestr]
	M.ammo_states = magazine_icondata_states[typestr]

/proc/magazine_icondata_cache_add(var/obj/item/ammo_magazine/M)
	var/list/icon_keys = list()
	var/list/ammo_states = list()
	var/list/states = icon_states(M.icon)
	for(var/i = 0, i <= M.max_ammo, i++)
		var/ammo_state = "[M.icon_state]-[i]"
		if(ammo_state in states)
			icon_keys += i
			ammo_states += ammo_state

	magazine_icondata_keys["[M.type]"] = icon_keys
	magazine_icondata_states["[M.type]"] = ammo_states

