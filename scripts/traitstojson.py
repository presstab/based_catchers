import csv
import json

csvfile = open('traits.csv', 'r')
reader = csv.reader(csvfile)

i = 0
j = 0
for row in reader:
	if i < 1:
		i = i + 1
		continue

	attributes = [
		{
			"trait_type": "Armor",
			"value": row[0]
		},
		{
			"trait_type": "Helmet",
			"value": row[1]
		},
		{
			"trait_type": "Eyes",
			"value": row[2]
		},
		{
			"trait_type": "Mouth",
			"value": row[3]
		},
		{
			"trait_type": "Accessory",
			"value": row[4]
		},
		{
			"trait_type": "Background",
			"value": row[5]
		},
		{
			"trait_type": "Strength",
			"value": int(row[6])
		},
		{
			"trait_type": "Valor",
			"value": int(row[7])
		},
		{
			"trait_type": "Intelligence",
			"value": int(row[8])
		},
		{
			"trait_type": "Speed",
			"value": int(row[9])
		},
		{
			"trait_type": "Magic",
			"value": int(row[10])
		}
	]

	json_obj = {
		"name": "Lone Squad #"+str(j),
		"description": "Lone Squad #"+str(j),
		"image":"http://192.169.6.71/ls_test/"+str(j)+".jpg",
		"attributes": attributes
	}
	j = j + 1
	i = i + 1

	json_str = json.dumps(json_obj)
	print(json_str)