/datum/ai_controller/basic_controller/living_limb_flesh
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_TARGET_MINIMUM_STAT = HARD_CRIT,
	)

	planning_subtrees = list(
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/basic_melee_attack_subtree
	)

/mob/living/basic/living_limb_flesh
	name = "living flesh"
	desc = "A vaguely leg or arm shaped flesh abomination. It pulses, like a heart."
	icon = 'icons/mob/simple/animal.dmi'
	icon_state = "limb"
	icon_living = "limb"
	mob_size = MOB_SIZE_SMALL
	basic_mob_flags = DEL_ON_DEATH
	faction = list(FACTION_HOSTILE)
	melee_damage_lower = 10
	melee_damage_upper = 10
	health = 20
	maxHealth = 20
	attack_sound = 'sound/weapons/bite.ogg'
	attack_vis_effect = ATTACK_EFFECT_BITE
	attack_verb_continuous = "tries desperately to attach to"
	attack_verb_simple = "try to attach to"
	mob_biotypes = MOB_ORGANIC | MOB_SPECIAL
	ai_controller = /datum/ai_controller/basic_controller/living_limb_flesh
	/// the meat bodypart we are currently inside, used to like drain nutrition and dismember and shit
	var/obj/item/bodypart/current_bodypart

/mob/living/basic/living_limb_flesh/Initialize(mapload, obj/item/bodypart/limb)
	. = ..()
	AddComponent(/datum/component/swarming, max_x = 8, max_y = 8)
	AddElement(/datum/element/death_drops, string_list(list(/obj/effect/gibspawner/generic)))
	if(!isnull(limb))
		register_to_limb(limb)

/mob/living/basic/living_limb_flesh/Destroy(force)
	. = ..()
	QDEL_NULL(current_bodypart)

/mob/living/basic/living_limb_flesh/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	. = ..()
	if(stat == DEAD)
		return
	if(isnull(current_bodypart) || isnull(current_bodypart.owner))
		return
	var/mob/living/carbon/human/victim = current_bodypart.owner
	if(prob(SPT_PROB(3, SSMOBS_DT)))
		to_chat(victim, span_warning("The thing posing as your limb makes you feel funny...")) //warn em
	//firstly as a sideeffect we drain nutrition from our host
	victim.adjust_nutrition(-1.5)

	if(!prob(SPT_PROB(1.5, SSMOBS_DT)))
		return

	if(istype(current_bodypart, /obj/item/bodypart/arm))
		var/list/candidates = list()
		for(var/atom/movable/movable in orange(victim, 1))
			if(movable.anchored)
				continue
			if(movable == victim)
				continue
			if(!victim.CanReach(movable))
				continue
			candidates += movable
		var/atom/movable/candidate = pick(candidates)
		if(isnull(candidate))
			return
		victim.start_pulling(candidate, supress_message = TRUE)
		victim.visible_message(span_warning("[victim][victim.p_s()] [current_bodypart] instinctually starts feeling [candidate]!"))
		return

	if(HAS_TRAIT(victim, TRAIT_IMMOBILIZED))
		return
	step(victim, pick(GLOB.cardinals))
	to_chat(victim, span_warning("Your [current_bodypart] moves on its own!"))


/mob/living/basic/living_limb_flesh/melee_attack(mob/living/carbon/human/target, list/modifiers, ignore_cooldown)
	. = ..()
	if (!ishuman(target) || target.stat == DEAD || HAS_TRAIT(target, TRAIT_NODISMEMBER))
		return

	var/list/zone_candidates = target.get_missing_limbs()
	for(var/obj/item/bodypart/bodypart in target.bodyparts)
		if(bodypart.body_zone == BODY_ZONE_HEAD || bodypart.body_zone == BODY_ZONE_CHEST)
			continue
		if(HAS_TRAIT(bodypart, TRAIT_IGNORED_BY_LIVING_FLESH))
			continue
		if(bodypart.bodypart_flags & BODYPART_UNREMOVABLE)
			continue
		if(bodypart.brute_dam < 20)
			continue
		zone_candidates += bodypart.body_zone

	if(!length(zone_candidates))
		return

	var/target_zone = pick(zone_candidates)
	var/obj/item/bodypart/target_part = target.get_bodypart(target_zone)
	if(isnull(target_part))
		target.emote("agony") // Ark Station 13 Edit // dismember already makes them scream so only do this if we aren't doing that
	else
		target_part.dismember()

	var/part_type
	switch(target_zone)
		if(BODY_ZONE_L_ARM)
			part_type = /obj/item/bodypart/arm/left/flesh
		if(BODY_ZONE_R_ARM)
			part_type = /obj/item/bodypart/arm/right/flesh
		if(BODY_ZONE_L_LEG)
			part_type = /obj/item/bodypart/leg/left/flesh
		if(BODY_ZONE_R_LEG)
			part_type = /obj/item/bodypart/leg/right/flesh

	target.visible_message(span_danger("[src] [target_part ? "tears off and attaches itself" : "attaches itself"] to where [target][target.p_s()] limb used to be!"))
	current_bodypart = new part_type(TRUE) //dont_spawn_flesh, we cant use named arguments here
	current_bodypart.replace_limb(target, TRUE)
	forceMove(current_bodypart)
	register_to_limb(current_bodypart)

/mob/living/basic/living_limb_flesh/proc/register_to_limb(obj/item/bodypart/part)
	ai_controller.set_ai_status(AI_STATUS_OFF)
	RegisterSignal(part, COMSIG_BODYPART_REMOVED, PROC_REF(on_limb_lost))
	RegisterSignal(part.owner, COMSIG_LIVING_DEATH, PROC_REF(owner_died))
	RegisterSignal(part.owner, COMSIG_LIVING_ELECTROCUTE_ACT, PROC_REF(owner_shocked)) //detach if we are shocked, not beneficial for the host but hey its a sideeffect

/mob/living/basic/living_limb_flesh/proc/owner_shocked(datum/source, shock_damage, source, siemens_coeff, flags)
	SIGNAL_HANDLER
	if(shock_damage < 10)
		return
	var/mob/living/carbon/human/part_owner = current_bodypart.owner
	if(!detach_self())
		return
	var/turf/our_location = get_turf(src)
	our_location.visible_message(span_warning("[part_owner][part_owner.p_s()] [current_bodypart] begins to convulse wildly!"))

/mob/living/basic/living_limb_flesh/proc/owner_died(datum/source, gibbed)
	SIGNAL_HANDLER
	if(gibbed)
		return
	addtimer(CALLBACK(src, PROC_REF(detach_self)), 1 SECONDS) //we need new hosts, dead people suck!

/mob/living/basic/living_limb_flesh/proc/detach_self()
	if(isnull(current_bodypart))
		return FALSE
	current_bodypart.dismember()
	return TRUE//on_limb_lost should be called after that

/mob/living/basic/living_limb_flesh/proc/on_limb_lost(atom/movable/source, mob/living/carbon/old_owner, dismembered)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_BODYPART_REMOVED)
	UnregisterSignal(old_owner, COMSIG_LIVING_ELECTROCUTE_ACT)
	UnregisterSignal(old_owner, COMSIG_LIVING_DEATH)
	addtimer(CALLBACK(src, PROC_REF(wake_up), source), 2 SECONDS)

/mob/living/basic/living_limb_flesh/proc/wake_up(atom/limb)
	ai_controller.set_ai_status(AI_STATUS_ON)
	forceMove(limb.drop_location())
	current_bodypart = null
	qdel(limb)
	visible_message(span_warning("[src] begins flailing around!"))
	Shake(6, 6, 0.5 SECONDS)
