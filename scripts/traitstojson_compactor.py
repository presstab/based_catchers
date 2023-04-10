import csv
import json

csvfile = open('traits_compactor.csv', 'r')
reader = csv.reader(csvfile)

i = 0
j = 0
for row in reader:
	if i < 1:
		i = i + 1
		continue

	attributes = [
		{
			"trait_type": "Strength",
			"value": int(row[0])
		},
		{
			"trait_type": "Valor",
			"value": int(row[1])
		},
		{
			"trait_type": "Intelligence",
			"value": int(row[2])
		},
		{
			"trait_type": "Speed",
			"value": int(row[3])
		},
		{
			"trait_type": "Magic",
			"value": int(row[4])
		}
	]

	json_obj = {
		"name": "Compactor #"+str(j),
		"description": "Compactor #"+str(j),
		"image":"http://192.169.6.71/compactor/compactor.jpg",
		"attributes": attributes
	}
	j = j + 1
	i = i + 1

	json_str = json.dumps(json_obj)
	print(json_str)