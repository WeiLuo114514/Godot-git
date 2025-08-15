#ground
extends Node3D

@export var gridMap : GridMap
var finish := false

func finish_game():
	finish = true
	gridMap.position = Vector3(0,-2.2,0)

func total_in():
	if finish:return
	gridMap.position = Vector3(0,-1.8,0)

func total_out():
	if finish:return
	gridMap.position = Vector3(0,0,0)
