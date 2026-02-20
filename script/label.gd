# CoinLabel.gd
extends Label

func _ready():
    PlayerData.coins_changed.connect(_on_coins_changed)
    text = "Coins: %d" % PlayerData.coins

func _on_coins_changed(new_coin_count: int):
    text = "Coins: %d" % new_coin_count
