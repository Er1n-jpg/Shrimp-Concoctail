class_name DrinkJudge
extends RefCounted
## Rates a drink 1-5 stars. Pure logic, no nodes, so it's easy to tune.

const HATED_PENALTY := 1.0
const RULE_PENALTY := 1.0
## Per ingredient that isn't required, liked, or hated.
const UNRELATED_PENALTY := 0.5
const LIKED_BONUS := 0.5
const LIKED_BONUS_MAX := 1.0
const SPEED_BONUS := 0.5
## Speed bonus if at least this fraction of patience is left when served.
const SPEED_BONUS_THRESHOLD := 0.5
const EXTRA_ALCOHOL_BONUS := 0.5
const EXTRA_ALCOHOL_BONUS_MAX := 1.0


## contents: { ingredient_id: pour_count }
static func rate(contents: Dictionary, customer: CustomerData, required: PackedStringArray, patience_left_ratio: float) -> int:
	return clampi(roundi(score(contents, customer, required, patience_left_ratio)), 1, 5)


static func score(contents: Dictionary, customer: CustomerData, required: PackedStringArray, patience_left_ratio: float) -> float:
	if contents.is_empty():
		return 1.0

	# Required ingredients carry the drink: all of them = 5 stars before bonuses/penalties.
	var s := 1.0
	if required.is_empty():
		s += 4.0
	else:
		var present := 0
		for id in required:
			if contents.has(id):
				present += 1
		s += 4.0 * present / required.size()

	var liked_count := 0
	for id: String in contents:
		if required.has(id):
			continue
		if customer.hated.has(id):
			s -= HATED_PENALTY
		elif customer.liked.has(id):
			liked_count += 1
		else:
			s -= UNRELATED_PENALTY
	s += minf(liked_count * LIKED_BONUS, LIKED_BONUS_MAX)

	match customer.rule:
		CustomerData.Rule.GREEN_ONLY:
			for id: String in contents:
				var ing := Database.ingredient(id)
				if ing == null or not ing.has_tag("green"):
					s -= RULE_PENALTY
		CustomerData.Rule.MORE_ALCOHOL:
			var alcohol_pours := 0
			for id: String in contents:
				var ing := Database.ingredient(id)
				if ing != null and ing.has_tag("alcohol"):
					alcohol_pours += int(contents[id])
			var required_alcohol := 0
			for id in required:
				var ing := Database.ingredient(id)
				if ing != null and ing.has_tag("alcohol"):
					required_alcohol += 1
			var extra := alcohol_pours - required_alcohol
			if extra > 0:
				s += minf(extra * EXTRA_ALCOHOL_BONUS, EXTRA_ALCOHOL_BONUS_MAX)

	if patience_left_ratio >= SPEED_BONUS_THRESHOLD:
		s += SPEED_BONUS

	return s
