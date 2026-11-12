extends Node
signal balance_changed(new_balance: int)

var souls: int = 0

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
