extends HBoxContainer

# Below is an example of a shop UI, showing the player's inventory
# and the shop's.
# Each inventory has a ControlList, which handles
# adding/removing/moving Controls as it changes.
# Changes are handled when calling update_list.


@export var player_inventory: Array[SampleShopItem]
@export var shop_inventory: Array[SampleShopItem]

func _ready():
	# Set up the ControlLists
	
	var player_inventory_control_list := $%PlayerInventoryControlList
	# ControlList needs a key for each item.
	# This tells it how to get an item's key.
	player_inventory_control_list.set_item_key(func(item): return item.id)
	# Tell ControlList how to create a Control for a given item.
	player_inventory_control_list.set_control_factory(create_player_item_control)
	# Give ControlList the initial list of items.
	# This should be called again whenever the list changes.
	player_inventory_control_list.update_list(player_inventory)
	
	var shop_inventory_control_list := $%ShopInventoryControlList
	shop_inventory_control_list.set_item_key(func(item): return item.id)
	shop_inventory_control_list.set_control_factory(create_shop_item_control)
	shop_inventory_control_list.update_list(shop_inventory)
	
	misc_setup()

## Creates sample_shop_item for the player's inventory
func create_player_item_control(item: SampleShopItem) -> Control:
	var control = load("res://sample_shop_item.tscn").instantiate()
	control.item = item
	control.sell_mode = true
	control.trade_pressed.connect(sell.bind(item))
	return control

## Creates sample_shop_item for the shop's inventory
func create_shop_item_control(item: SampleShopItem) -> Control:
	var control = load("res://sample_shop_item.tscn").instantiate()
	control.item = item
	control.sell_mode = false
	control.trade_pressed.connect(buy.bind(item))
	return control

func sell(item: SampleShopItem):
	player_inventory.erase(item)
	$%PlayerInventoryControlList.update_list(player_inventory)
	shop_inventory.append(item)
	$%ShopInventoryControlList.update_list(shop_inventory)

func buy(item: SampleShopItem):
	shop_inventory.erase(item)
	$%ShopInventoryControlList.update_list(shop_inventory)
	player_inventory.append(item)
	$%PlayerInventoryControlList.update_list(player_inventory)


# Setup that's not relevant for demoing ControlList

func misc_setup() -> void:
	$%PlayerSellAllButton.pressed.connect(
		func():
			shop_inventory.append_array(player_inventory)
			player_inventory.clear()
			$%PlayerInventoryControlList.update_list(player_inventory)
			$%ShopInventoryControlList.update_list(shop_inventory)
	)
	$%ShopBuyAllButton.pressed.connect(
		func():
			player_inventory.append_array(shop_inventory)
			shop_inventory.clear()
			$%PlayerInventoryControlList.update_list(player_inventory)
			$%ShopInventoryControlList.update_list(shop_inventory)
	)
	$%PlayerSortNameButton.pressed.connect(
		func():
			sort_by_name(player_inventory)
			$%PlayerInventoryControlList.update_list(player_inventory)
	)
	$%PlayerSortPriceButton.pressed.connect(
		func():
			sort_by_price(player_inventory)
			$%PlayerInventoryControlList.update_list(player_inventory)
	)
	$%ShopSortNameButton.pressed.connect(
		func():
			sort_by_name(shop_inventory)
			$%ShopInventoryControlList.update_list(shop_inventory)
	)
	$%ShopSortPriceButton.pressed.connect(
		func():
			sort_by_price(shop_inventory)
			$%ShopInventoryControlList.update_list(shop_inventory)
	)

func sort_by_name(items: Array[SampleShopItem]):
	items.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)

func sort_by_price(items: Array[SampleShopItem]):
	items.sort_custom(func(a, b): return a.price > b.price)
