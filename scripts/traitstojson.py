import csv
import json

csvfile = open('traits.csv', 'r')
reader = csv.reader(csvfile)

i = 0
j = 0
for row in reader:
	if i < 2:
		i = i + 1
		continue

	##print(row)
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
		}
	]

	json_obj = {
		"name": "Based Catcher #"+str(j),
		"description": "Based Catcher #"+str(j),
		"image":"",
		"attributes": attributes
	}
	j = j + 1
	i = i + 1

	json_str = json.dumps(json_obj)
	print(json_str)