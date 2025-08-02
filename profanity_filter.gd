class_name ProfanityFilter

# Static profanity filter class

static func get_banned_words() -> Array:
	return [
		# Common profanity
		"fuck", "fucker", "fucking", "fucked", "fucks", "fuk", "fuq", "fuc",
		"shit", "shitty", "shitting", "shat", "sh1t", "shi+",
		"ass", "asshole", "asses", "assh0le", "azzhole",
		"bitch", "bitches", "bitching", "b1tch", "biatch",
		"damn", "damned", "dammit", "damnit",
		"hell", "hells",
		"dick", "dicks", "d1ck", "dic", "dik",
		"cock", "cocks", "c0ck", "cok",
		"pussy", "pussies", "puss1", "pussi",
		"penis", "pen1s", "pnis",
		"vagina", "vag1na",
		"cunt", "cunts", "kunt",
		"bastard", "bastards", "b@stard",
		"whore", "whores", "wh0re", "hor",
		"slut", "sluts", "sl*t",
		
		# Racial slurs and hate speech
		"nigger", "nigga", "niger", "niga", "n1gger", "n1gga",
		"faggot", "fag", "fgt", "fagot", "f@g",
		"retard", "retarded", "tard", "ret@rd",
		"spic", "sp1c",
		"chink", "ch1nk",
		"kike", "k1ke",
		"dyke", "d*ke",
		
		# Sexual terms
		"sex", "sexy", "s3x",
		"porn", "porno", "p0rn",
		"nude", "nudes", "nud3",
		"boob", "boobs", "tit", "tits", "t1t", "b00b",
		"anal", "anus", "@nal",
		"rape", "raped", "raping", "r@pe",
		"dildo", "d1ldo",
		"cum", "cumming", "cums", "jizz", "j1zz",
		"fap", "fapping",
		
		# Drug references
		"cocaine", "coke", "crack",
		"meth", "heroin", "weed", "marijuana",
		
		# Violence
		"kill", "murder", "k1ll",
		"nazi", "n@zi",
		"hitler", "h1tler",
		
		# Common misspellings and leetspeak
		"azz", "a55", "@ss",
		"b!tch", "b*tch",
		"5hit", "5h1t",
		"fvck", "fxck",
		"d!ck", "d*ck",
		"p*ssy", "pu55y"
	]

static func filter_text(text: String) -> String:
	var filtered = text
	var lower_text = text.to_lower()
	var banned_words = get_banned_words()
	
	# First pass: check for exact word matches
	for word in banned_words:
		var i = 0
		while i < lower_text.length():
			var index = lower_text.find(word, i)
			if index == -1:
				break
			
			# Check if it's a word boundary
			var is_word_start = index == 0 or not lower_text[index - 1].is_valid_identifier()
			var is_word_end = index + word.length() >= lower_text.length() or not lower_text[index + word.length()].is_valid_identifier()
			
			if is_word_start and is_word_end:
				# Replace with asterisks
				var replacement = "*".repeat(word.length())
				filtered = filtered.substr(0, index) + replacement + filtered.substr(index + word.length())
				lower_text = lower_text.substr(0, index) + replacement + lower_text.substr(index + word.length())
			
			i = index + 1
	
	# Second pass: check for words within other words (only for 4+ letter words)
	for word in banned_words:
		if word.length() >= 4:
			var i = 0
			while i < lower_text.length():
				var index = lower_text.find(word, i)
				if index == -1:
					break
				
				# Replace with asterisks
				var replacement = "*".repeat(word.length())
				filtered = filtered.substr(0, index) + replacement + filtered.substr(index + word.length())
				lower_text = lower_text.substr(0, index) + replacement + lower_text.substr(index + word.length())
				
				i = index + replacement.length()
	
	return filtered

static func is_appropriate(text: String) -> bool:
	var lower_text = text.to_lower()
	var banned_words = get_banned_words()
	
	for word in banned_words:
		# Check exact word matches
		var i = 0
		while i < lower_text.length():
			var index = lower_text.find(word, i)
			if index == -1:
				break
			
			# Check if it's a word boundary
			var is_word_start = index == 0 or not lower_text[index - 1].is_valid_identifier()
			var is_word_end = index + word.length() >= lower_text.length() or not lower_text[index + word.length()].is_valid_identifier()
			
			if is_word_start and is_word_end:
				return false
			
			# Also check if longer words contain inappropriate content
			if word.length() >= 4:
				return false
			
			i = index + 1
	
	return true