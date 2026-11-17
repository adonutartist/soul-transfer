extends Node
signal balance_changed(new_balance: int)
signal upgrades_changed

var souls: int = 0
var purchased_upgrades: Dictionary = {}

func add_souls(amount: int) -> void:
	if amount <= 0:
		return
	souls += amount
	balance_changed.emit(souls)
	print("Souls: ", souls)

func can_afford(amount: int) -> bool:
	return amount > 0 and souls >= amount

func spend_souls(amount: int) -> bool:
	if not can_afford(amount):
		return false
	souls -= amount
	balance_changed.emit(souls)
	print("Souls: ", souls)
	return true

func purchase_upgrade(
	upgrade_id: String, character_class: String,
	stat: String, amount: float
) -> void:
	if purchased_upgrades.has(upgrade_id):
		return
	purchased_upgrades[upgrade_id] = {
		"class": character_class,
		"stat": stat, "amount": amount
	}
	upgrades_changed.emit()

func has_upgrade(upgrade_id: String) -> bool:
	return purchased_upgrades.has(upgrade_id)

func get_upgrade_total(character_class: String, stat: String) -> float:
	var total := 0.0
	for upgrade in purchased_upgrades.values():
		if upgrade["class"] == character_class and upgrade["stat"] == stat:
			total += float(upgrade["amount"])
	return total
