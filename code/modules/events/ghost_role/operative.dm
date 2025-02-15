/datum/round_event_control/operative
	name = "Lone Operative"
	typepath = /datum/round_event/ghost_role/operative
	weight = 0 //its weight is relative to how much stationary and neglected the nuke disk is. See nuclearbomb.dm. Shouldn't be dynamic hijackable.
	max_occurrences = 1
	category = EVENT_CATEGORY_INVASION
	description = "A single nuclear operative assaults the station."

	track = EVENT_TRACK_ROLESET
	tags = list(TAG_DESTRUCTIVE, TAG_COMBAT)

/datum/round_event/ghost_role/operative
	minimum_required = 1
	role_name = "lone operative"
	fakeable = FALSE

/datum/round_event/ghost_role/operative/spawn_role()
	var/list/candidates = get_candidates(ROLE_OPERATIVE, ROLE_LONE_OPERATIVE)
	if(!candidates.len)
		return NOT_ENOUGH_PLAYERS

	var/mob/dead/selected = pick_n_take(candidates)

	var/spawn_location = find_space_spawn()
	if(isnull(spawn_location))
		return MAP_ERROR

	var/mob/living/carbon/human/operative = new(spawn_location)
	operative.randomize_human_appearance(~RANDOMIZE_SPECIES)
	operative.dna.update_dna_identity()
	var/datum/mind/Mind = new /datum/mind(selected.key)
	Mind.set_assigned_role(SSjob.GetJobType(/datum/job/lone_operative))
	Mind.special_role = ROLE_LONE_OPERATIVE
	Mind.active = TRUE
	Mind.transfer_to(operative)
	if(!operative.client?.prefs.read_preference(/datum/preference/toggle/nuke_ops_species))
		var/species_type = operative.client.prefs.read_preference(/datum/preference/choiced/species)
		operative.set_species(species_type) //Apply the preferred species to our freshly-made body.

	Mind.add_antag_datum(/datum/antagonist/nukeop/lone)

	message_admins("[ADMIN_LOOKUPFLW(operative)] has been made into lone operative by an event.")
	operative.log_message("was spawned as a lone operative by an event.", LOG_GAME)
	spawned_mobs += operative
	return SUCCESSFUL_SPAWN
