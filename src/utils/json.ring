# Copyright (c) 2026 Youssef Saeed <youssefelkholey@gmail.com>
# All rights reserved.

###############################################################################
#                     JSON Library for Ring Programming Language
#                         Pure Ring Implementation v1.2
#                    Parser, Generator, and Object Manipulation
###############################################################################

# ==============================================================================
# Constants and Character Codes
# ==============================================================================

# JSON Value Type Constants
JSON_NULL    = 0
JSON_BOOL    = 1
JSON_NUMBER  = 2
JSON_STRING  = 3
JSON_ARRAY   = 4
JSON_OBJECT  = 5

# Sentinel strings for JSON booleans (Ring has no boolean type).
# A parsed "true" is the STRING "__JSON_TRUE__", not the number 1.
JSON_TRUE_SENTINEL  = "__JSON_TRUE__"
JSON_FALSE_SENTINEL = "__JSON_FALSE__"

# Character codes
CHAR_TAB       = char(9)
CHAR_LF        = char(10)
CHAR_CR        = char(13)
CHAR_SPACE     = char(32)
CHAR_QUOTE     = char(34)
CHAR_BACKSLASH = char(92)
CHAR_SLASH     = char(47)
CHAR_BACKSPACE = char(8)
CHAR_FORMFEED  = char(12)

# ==============================================================================
# Convenience Functions (Procedural API)
# ==============================================================================

###############################################################################
# Convert JSON string to Pure Ring List (Association Lists for Objects)
# Returns: List (e.g. [ ["name", "john"], ["age", 30] ])
###############################################################################
func json2list cJson
    # Parse string to intermediate objects
    xData = json_parse(cJson)
    
    # Convert recursively to pure lists
    return _json_obj2list_recursive(xData)

###############################################################################
# Convert Pure Ring List to JSON string
# Detects Association Lists [[k,v]...] and converts them to JSON Objects {}
###############################################################################
func list2json aList
    # Convert pure lists to intermediate objects
    xData = _json_list2obj_recursive(aList)
    
    # Generate JSON string
    return json_stringify(xData)

###############################################################################
# JSON boolean values (sentinel mechanism, same as simplejson C extension).
# Ring has no boolean type: True/False are the numbers 1/0, indistinguishable
# from numbers. Parsed JSON booleans are therefore sentinel strings.
###############################################################################

###############################################################################
# Create a JSON true value
###############################################################################
func json_true
    return JSON_TRUE_SENTINEL

###############################################################################
# Create a JSON false value
###############################################################################
func json_false
    return JSON_FALSE_SENTINEL

###############################################################################
# Check if value is JSON true
###############################################################################
func json_is_true xValue
    if type(xValue) = "STRING"
        return xValue = JSON_TRUE_SENTINEL
    ok
    return False

###############################################################################
# Check if value is JSON false
###############################################################################
func json_is_false xValue
    if type(xValue) = "STRING"
        return xValue = JSON_FALSE_SENTINEL
    ok
    return False

###############################################################################
# Check if value is a JSON boolean (true or false)
###############################################################################
func json_is_boolean xValue
    return json_is_true(xValue) or json_is_false(xValue)

###############################################################################
# Convert JSON boolean sentinel to Ring boolean (1/0).
# Raises an error for non-boolean values.
###############################################################################
func json_to_boolean xValue
    if json_is_true(xValue)
        return True
    ok
    if json_is_false(xValue)
        return False
    ok
    raise("Not a JSON boolean value")

# ==============================================================================
# Internal Helper Functions
# ==============================================================================

func _json_obj2list_recursive xValue
    # Handle JSONObject Class
    if type(xValue) = "OBJECT" and classname(xValue) = "jsonobject"
        aResult = []
        # getItems() returns the internal list of [key, value]
        aItems = xValue.getItems()
        for i = 1 to len(aItems)
            cKey = aItems[i][1]
            xVal = aItems[i][2]
            add(aResult, [ cKey, _json_obj2list_recursive(xVal) ])
        next
        return aResult
    ok
    
    # Handle Arrays (Lists)
    if type(xValue) = "LIST"
        aResult = []
        for i = 1 to len(xValue)
            add(aResult, _json_obj2list_recursive(xValue[i]))
        next
        return aResult
    ok
    
    # Primitives (String, Number, etc)
    return xValue

func _json_list2obj_recursive xValue
    if type(xValue) != "LIST"
        return xValue
    ok
    
    # Heuristic: Is this an Association List (Object) or a standard Array?
    # Logic: It's an object if it's a list of lists, where every sublist is size 2
    # and the first element (Key) is a string.
    
    lIsObject = False
    if len(xValue) > 0
        lIsObject = True
        for item in xValue
            if not (type(item) = "LIST" and len(item) = 2 and type(item[1]) = "STRING")
                lIsObject = False
                exit
            ok
        next
    ok

    if lIsObject
        # Convert to JSONObject
        oObj = new JSONObject
        for item in xValue
            # item[1] is Key, item[2] is Value
            oObj.set(item[1], _json_list2obj_recursive(item[2]))
        next
        return oObj
    else
        # Convert to standard Array
        aArr = []
        for i = 1 to len(xValue)
            add(aArr, _json_list2obj_recursive(xValue[i]))
        next
        return aArr
    ok

###############################################################################
# Parse JSON string to Ring data structure
###############################################################################
func json_parse cJsonString
    oParser = new JSONParser
    xResult = oParser.parse(cJsonString)
    return xResult

###############################################################################
# Parse JSON string with error handling
###############################################################################
func json_parse_safe cJsonString
    oParser = new JSONParser
    xResult = oParser.parse(cJsonString)
    aReturn = []
    add(aReturn, xResult)
    add(aReturn, oParser.getError())
    return aReturn

###############################################################################
# Parse JSON with custom max depth
###############################################################################
func json_parse_depth cJsonString, nMaxDepth
    oParser = new JSONParser
    oParser.setMaxDepth(nMaxDepth)
    xResult = oParser.parse(cJsonString)
    return xResult

###############################################################################
# Convert Ring data structure to JSON string (compact)
###############################################################################
func json_stringify xValue
    oGenerator = new JSONGenerator
    return oGenerator.toString(xValue)

###############################################################################
# Convert Ring data structure to JSON string (pretty printed)
###############################################################################
func json_pretty xValue
    oGenerator = new JSONGenerator
    return oGenerator.toPrettyString(xValue)

###############################################################################
# Convert Ring data structure to JSON with custom indent
###############################################################################
func json_pretty_indent xValue, cIndent
    oGenerator = new JSONGenerator
    oGenerator.setIndent(cIndent)
    return oGenerator.toPrettyString(xValue)

###############################################################################
# Create new JSON object
###############################################################################
func json_object
    return new JSONObject

###############################################################################
# Create JSON object from list of pairs
###############################################################################
func json_object_from aList
    oObj = new JSONObject
    for i = 1 to len(aList)
        if type(aList[i]) = "LIST" and len(aList[i]) >= 2
            oObj.set(aList[i][1], aList[i][2])
        ok
    next
    return oObj

###############################################################################
# Get value from JSON object
###############################################################################
func json_get xObj, cKey
    if type(xObj) = "OBJECT" and classname(xObj) = "jsonobject"
        return xObj.getValue(cKey)
    ok
    return NULL

###############################################################################
# Set value in JSON object
###############################################################################
func json_set xObj, cKey, xValue
    if type(xObj) = "OBJECT" and classname(xObj) = "jsonobject"
        xObj.set(cKey, xValue)
        return True
    ok
    return False

###############################################################################
# Get value at path
###############################################################################
func json_path_get xData, cPath
    oPath = new JSONPath
    return oPath.getValue(xData, cPath)

###############################################################################
# Set value at path
###############################################################################
func json_path_set xData, cPath, xValue
    oPath = new JSONPath
    return oPath.set(xData, cPath, xValue)

###############################################################################
# Get type of JSON value
###############################################################################
func json_typeof xValue
    # NULL (the empty string in Ring) is JSON null
    if isNull(xValue)
        return JSON_NULL
    ok
    
    cType = type(xValue)
    
    if cType = "STRING"
        # Boolean sentinels must be checked before generic strings
        if xValue = JSON_TRUE_SENTINEL or xValue = JSON_FALSE_SENTINEL
            return JSON_BOOL
        ok
        return JSON_STRING
    ok
    
    if cType = "NUMBER"
        return JSON_NUMBER
    ok
    
    if cType = "LIST"
        return JSON_ARRAY
    ok
    
    if cType = "OBJECT"
        if classname(xValue) = "jsonobject"
            return JSON_OBJECT
        ok
    ok
    
    return JSON_NULL

###############################################################################
# Get type name of JSON value
###############################################################################
func json_typename xValue
    nType = json_typeof(xValue)
    
    switch nType
        on JSON_NULL
            return "null"
        on JSON_BOOL
            return "boolean"
        on JSON_NUMBER
            return "number"
        on JSON_STRING
            return "string"
        on JSON_ARRAY
            return "array"
        on JSON_OBJECT
            return "object"
    off
    
    return "unknown"

###############################################################################
# Check if value is a JSON object
###############################################################################
func json_isobject xValue
    return type(xValue) = "OBJECT" and classname(xValue) = "jsonobject"

###############################################################################
# Check if value is a JSON array
###############################################################################
func json_isarray xValue
    return type(xValue) = "LIST"

###############################################################################
# Deep copy a JSON value
###############################################################################
func json_deepcopy xValue
    # isNull() so the number 0 is not mistaken for null
    if isNull(xValue)
        return NULL
    ok
    
    cType = type(xValue)
    
    if cType = "STRING" or cType = "NUMBER"
        return xValue
    ok
    
    if cType = "LIST"
        aNew = []
        for i = 1 to len(xValue)
            add(aNew, json_deepcopy(xValue[i]))
        next
        return aNew
    ok
    
    if cType = "OBJECT" and classname(xValue) = "jsonobject"
        return xValue.clone()
    ok
    
    return xValue

###############################################################################
# Merge two JSON objects
###############################################################################
func json_merge oObj1, oObj2
    if not json_isobject(oObj1) or not json_isobject(oObj2)
        return oObj1
    ok
    
    oResult = oObj1.clone()
    oResult.merge(oObj2)
    return oResult

###############################################################################
# Compare two JSON values for equality
###############################################################################
func json_equals xVal1, xVal2
    # Handle JSON null (Ring NULL / empty string).
    # isNull() distinguishes null from the number 0 and from sentinels.
    if isNull(xVal1) and isNull(xVal2)
        return True
    ok
    if isNull(xVal1) or isNull(xVal2)
        return False
    ok
    
    # Must be same JSON type (sentinel booleans are strings but compare
    # correctly via exact string equality below)
    if json_typeof(xVal1) != json_typeof(xVal2)
        return False
    ok
    
    cType = type(xVal1)
    
    # Primitives (string comparison is case-sensitive and exact)
    if cType = "STRING" or cType = "NUMBER"
        return xVal1 = xVal2
    ok
    
    # Arrays
    if cType = "LIST"
        if len(xVal1) != len(xVal2)
            return False
        ok
        for i = 1 to len(xVal1)
            if not json_equals(xVal1[i], xVal2[i])
                return False
            ok
        next
        return True
    ok
    
    # Objects
    if cType = "OBJECT"
        if classname(xVal1) = "jsonobject" and classname(xVal2) = "jsonobject"
            aKeys1 = xVal1.keys()
            aKeys2 = xVal2.keys()
            
            if len(aKeys1) != len(aKeys2)
                return False
            ok
            
            for i = 1 to len(aKeys1)
                cKey = aKeys1[i]
                if not xVal2.hasKey(cKey)
                    return False
                ok
                if not json_equals(xVal1.getValue(cKey), xVal2.getValue(cKey))
                    return False
                ok
            next
            return True
        ok
    ok
    
    return False

###############################################################################
# Validate JSON string
###############################################################################
func json_validate cJsonString
    oParser = new JSONParser
    oParser.parse(cJsonString)
    return oParser.getError() = ""

###############################################################################
# Get validation error
###############################################################################
func json_error cJsonString
    oParser = new JSONParser
    oParser.parse(cJsonString)
    return oParser.getError()

###############################################################################
# Read JSON from file
###############################################################################
func json_read_file cFilename
    # fExists() prevents read() from raising a runtime error on missing files
    if not fExists(cFilename)
        return NULL
    ok
    cContent = read(cFilename)
    if cContent = NULL or cContent = ""
        return NULL
    ok
    return json_parse(cContent)

###############################################################################
# Write JSON to file
###############################################################################
func json_write_file cFilename, xValue
    cJson = json_stringify(xValue)
    write(cFilename, cJson)

###############################################################################
# Write pretty JSON to file
###############################################################################
func json_write_file_pretty cFilename, xValue
    cJson = json_pretty(xValue)
    write(cFilename, cJson)

###############################################################################
# Array helper - find index of value
###############################################################################
func json_array_find aArr, xValue
    for i = 1 to len(aArr)
        if json_equals(aArr[i], xValue)
            return i
        ok
    next
    return 0

###############################################################################
# Create formatted error with context
###############################################################################
func json_format_error cJsonString, cError
    if cError = "" or cError = NULL
        return "No error"
    ok
    
    # Extract position from error message
    nPos = 0
    nSearchStart = substr(cError, "position")
    if nSearchStart > 0
        cAfterPos = substr(cError, nSearchStart + 9)
        cNumStr = ""
        for i = 1 to len(cAfterPos)
            c = substr(cAfterPos, i, 1)
            if c >= "0" and c <= "9"
                cNumStr = cNumStr + c
            else
                if cNumStr != ""
                    exit
                ok
            ok
        next
        if cNumStr != ""
            nPos = number(cNumStr)
        ok
    ok
    
    if nPos > 0 and nPos <= len(cJsonString)
        nStart = nPos - 20
        if nStart < 1
            nStart = 1
        ok
        nEnd = nPos + 20
        if nEnd > len(cJsonString)
            nEnd = len(cJsonString)
        ok
        cContext = substr(cJsonString, nStart, nEnd - nStart + 1)
        cPointer = ""
        for i = 1 to nPos - nStart
            cPointer = cPointer + " "
        next
        cPointer = cPointer + "^"
        return cError + CHAR_LF + "Context: " + cContext + CHAR_LF + "         " + cPointer
    ok
    
    return cError

###############################################################################
# Minify JSON string (remove whitespace)
###############################################################################
func json_minify cJsonString
    # Use the parser error state, not the result value: a valid JSON "null"
    # parses to Ring NULL and must not be confused with a parse failure.
    oParser = new JSONParser
    xData = oParser.parse(cJsonString)
    if oParser.getError() != ""
        return cJsonString
    ok
    return json_stringify(xData)

###############################################################################
# Check if string is valid JSON
###############################################################################
func json_is_valid cJsonString
    return json_validate(cJsonString)

###############################################################################
# Get keys from JSON object
###############################################################################
func json_keys xObj
    if type(xObj) = "OBJECT" and classname(xObj) = "jsonobject"
        return xObj.keys()
    ok
    return []

###############################################################################
# Get values from JSON object
###############################################################################
func json_values xObj
    if type(xObj) = "OBJECT" and classname(xObj) = "jsonobject"
        return xObj.values()
    ok
    return []

###############################################################################
# Get length of JSON array or object
###############################################################################
func json_length xValue
    if type(xValue) = "LIST"
        return len(xValue)
    ok
    if type(xValue) = "OBJECT" and classname(xValue) = "jsonobject"
        return xValue.count()
    ok
    return 0

###############################################################################
# Remove key from JSON object
###############################################################################
func json_remove xObj, cKey
    if type(xObj) = "OBJECT" and classname(xObj) = "jsonobject"
        return xObj.remove(cKey)
    ok
    return False

###############################################################################
# Check if JSON object has key
###############################################################################
func json_has_key xObj, cKey
    if type(xObj) = "OBJECT" and classname(xObj) = "jsonobject"
        return xObj.hasKey(cKey)
    ok
    return False

# ==============================================================================
# JSONObject Class - Represents a JSON Object
# ==============================================================================

class JSONObject
    
    aItems = []
    
    ###########################################################################
    # Initialize empty object
    ###########################################################################
    func init
        aItems = []
        return self
    
    ###########################################################################
    # Set a key-value pair
    ###########################################################################
    func set cKey, xValue
        # Check if key already exists
        for i = 1 to len(aItems)
            if aItems[i][1] = cKey
                aItems[i][2] = xValue
                return self
            ok
        next
        # Add new key-value pair
        add(aItems, [cKey, xValue])
        return self
    
    ###########################################################################
    # Get value by key
    ###########################################################################
    func getValue cKey
        for i = 1 to len(aItems)
            if aItems[i][1] = cKey
                return aItems[i][2]
            ok
        next
        return NULL
    
    ###########################################################################
    # Check if key exists
    ###########################################################################
    func hasKey cKey
        for i = 1 to len(aItems)
            if aItems[i][1] = cKey
                return True
            ok
        next
        return False
    
    ###########################################################################
    # Get all keys
    ###########################################################################
    func keys
        aResult = []
        for i = 1 to len(aItems)
            add(aResult, aItems[i][1])
        next
        return aResult
    
    ###########################################################################
    # Get all values
    ###########################################################################
    func values
        aResult = []
        for i = 1 to len(aItems)
            add(aResult, aItems[i][2])
        next
        return aResult
    
    ###########################################################################
    # Get count of items
    ###########################################################################
    func count
        return len(aItems)
    
    ###########################################################################
    # Get items list (for internal use)
    ###########################################################################
    func getItems
        return aItems
    
    ###########################################################################
    # Remove a key
    ###########################################################################
    func remove cKey
        for i = 1 to len(aItems)
            if aItems[i][1] = cKey
                del(aItems, i)
                return True
            ok
        next
        return False
    
    ###########################################################################
    # Clear all items
    ###########################################################################
    func clear
        aItems = []
        return self
    
    ###########################################################################
    # Merge another JSONObject into this one
    ###########################################################################
    func merge oOther
        if type(oOther) = "OBJECT"
            if classname(oOther) = "jsonobject"
                aOtherKeys = oOther.keys()
                for i = 1 to len(aOtherKeys)
                    cKey = aOtherKeys[i]
                    set(cKey, oOther.getValue(cKey))
                next
            ok
        ok
        return self
    
    ###########################################################################
    # Clone this object
    ###########################################################################
    func clone
        oNew = new JSONObject
        for i = 1 to len(aItems)
            oNew.set(aItems[i][1], json_deepcopy(aItems[i][2]))
        next
        return oNew
    
    ###########################################################################
    # Convert to string representation
    ###########################################################################
    func tostring
        return json_stringify(self)

# ==============================================================================
# JSONParser Class - Parses JSON strings into Ring data structures
# ==============================================================================

class JSONParser
    
    cJson         = ""
    nPos          = 1
    nLength       = 0
    cError        = ""
    nMaxDepth     = 200   # Ring VM stack overflows near depth 500; keep well below
    nCurrentDepth = 0
    
    ###########################################################################
    # Main parse function
    ###########################################################################
    func parse cJsonString
        cJson         = cJsonString
        nPos          = 1
        nLength       = len(cJson)
        cError        = ""
        nCurrentDepth = 0
        
        # Skip UTF-8 BOM if present (EF BB BF = 239 187 191)
        if nLength >= 3
            if ascii(substr(cJson, 1, 1)) = 239 and 
               ascii(substr(cJson, 2, 1)) = 187 and 
               ascii(substr(cJson, 3, 1)) = 191
                nPos = 4
            ok
        ok
        
        skipWhitespace()
        
        if nPos > nLength
            cError = "Empty JSON string"
            return NULL
        ok
        
        xResult = parseValue()
        
        skipWhitespace()
        
        # Check for trailing content
        if cError = "" and nPos <= nLength
            cError = "Unexpected content after JSON value at position " + nPos
        ok
        
        return xResult
    
    ###########################################################################
    # Get last error message
    ###########################################################################
    func getError
        return cError
    
    ###########################################################################
    # Set maximum nesting depth
    ###########################################################################
    func setMaxDepth nDepth
        nMaxDepth = nDepth
        return self
    
    ###########################################################################
    # Parse any JSON value (with recursion depth protection)
    ###########################################################################
    func parseValue
        # Check recursion depth
        nCurrentDepth = nCurrentDepth + 1
        if nCurrentDepth > nMaxDepth
            cError = "Maximum nesting depth exceeded at position " + nPos
            nCurrentDepth = nCurrentDepth - 1
            return NULL
        ok
        
        skipWhitespace()
        
        if nPos > nLength
            cError = "Unexpected end of JSON"
            nCurrentDepth = nCurrentDepth - 1
            return NULL
        ok
        
        cChar = substr(cJson, nPos, 1)
        
        # Object
        if cChar = "{"
            xResult = parseObject()
            nCurrentDepth = nCurrentDepth - 1
            return xResult
        ok
        
        # Array
        if cChar = "["
            xResult = parseArray()
            nCurrentDepth = nCurrentDepth - 1
            return xResult
        ok
        
        # String
        if cChar = CHAR_QUOTE
            xResult = parseString()
            nCurrentDepth = nCurrentDepth - 1
            return xResult
        ok
        
        # Boolean true
        if cChar = "t"
            xResult = parseTrue()
            nCurrentDepth = nCurrentDepth - 1
            return xResult
        ok
        
        # Boolean false
        if cChar = "f"
            xResult = parseFalse()
            nCurrentDepth = nCurrentDepth - 1
            return xResult
        ok
        
        # Null
        if cChar = "n"
            xResult = parseNull()
            nCurrentDepth = nCurrentDepth - 1
            return xResult
        ok
        
        # Number
        if isdigit(cChar) or cChar = "-"
            xResult = parseNumber()
            nCurrentDepth = nCurrentDepth - 1
            return xResult
        ok
        
        cError = "Unexpected character '" + cChar + "' at position " + nPos
        nCurrentDepth = nCurrentDepth - 1
        return NULL
    
    ###########################################################################
    # Parse JSON Object
    ###########################################################################
    func parseObject
        oObj = new JSONObject
        
        nPos = nPos + 1   # Skip '{'
        skipWhitespace()
        
        # Empty object
        if nPos <= nLength and substr(cJson, nPos, 1) = "}"
            nPos = nPos + 1
            return oObj
        ok
        
        while nPos <= nLength
            skipWhitespace()
            
            # Parse key (must be a string)
            if nPos > nLength
                cError = "Unexpected end of JSON in object"
                return NULL
            ok
            
            if substr(cJson, nPos, 1) != CHAR_QUOTE
                cError = "Expected string key at position " + nPos
                return NULL
            ok
            
            cKey = parseString()
            if cError != ""
                return NULL
            ok
            
            skipWhitespace()
            
            # Expect ':'
            if nPos > nLength or substr(cJson, nPos, 1) != ":"
                cError = "Expected ':' after key at position " + nPos
                return NULL
            ok
            nPos = nPos + 1   # Skip ':'
            
            skipWhitespace()
            
            # Parse value
            xValue = parseValue()
            if cError != ""
                return NULL
            ok
            
            oObj.set(cKey, xValue)
            
            skipWhitespace()
            
            if nPos > nLength
                cError = "Unexpected end of JSON in object"
                return NULL
            ok
            
            cChar = substr(cJson, nPos, 1)
            
            if cChar = "}"
                nPos = nPos + 1
                return oObj
            ok
            
            if cChar = ","
                nPos = nPos + 1
                skipWhitespace()
                # Check for trailing comma
                if nPos <= nLength and substr(cJson, nPos, 1) = "}"
                    cError = "Trailing comma in object at position " + (nPos - 1)
                    return NULL
                ok
            else
                cError = "Expected ',' or '}' at position " + nPos
                return NULL
            ok
        end
        
        cError = "Unterminated object"
        return NULL
    
    ###########################################################################
    # Parse JSON Array
    ###########################################################################
    func parseArray
        aArr = []
        
        nPos = nPos + 1   # Skip '['
        skipWhitespace()
        
        # Empty array
        if nPos <= nLength and substr(cJson, nPos, 1) = "]"
            nPos = nPos + 1
            return aArr
        ok
        
        while nPos <= nLength
            skipWhitespace()
            
            # Parse value
            xValue = parseValue()
            if cError != ""
                return NULL
            ok
            
            add(aArr, xValue)
            
            skipWhitespace()
            
            if nPos > nLength
                cError = "Unexpected end of JSON in array"
                return NULL
            ok
            
            cChar = substr(cJson, nPos, 1)
            
            if cChar = "]"
                nPos = nPos + 1
                return aArr
            ok
            
            if cChar = ","
                nPos = nPos + 1
                skipWhitespace()
                # Check for trailing comma
                if nPos <= nLength and substr(cJson, nPos, 1) = "]"
                    cError = "Trailing comma in array at position " + (nPos - 1)
                    return NULL
                ok
            else
                cError = "Expected ',' or ']' at position " + nPos
                return NULL
            ok
        end
        
        cError = "Unterminated array"
        return NULL
    
    ###########################################################################
    # Parse JSON String (with full Unicode support)
    ###########################################################################
    func parseString
        cResult = ""
        
        nPos = nPos + 1   # Skip opening quote
        
        while nPos <= nLength
            cChar = substr(cJson, nPos, 1)
            
            # End of string
            if cChar = CHAR_QUOTE
                nPos = nPos + 1
                return cResult
            ok
            
            # Escape sequence
            if cChar = CHAR_BACKSLASH
                nPos = nPos + 1
                
                if nPos > nLength
                    cError = "Unexpected end of string escape"
                    return ""
                ok
                
                cEscaped = substr(cJson, nPos, 1)
                
                if cEscaped = "n"
                    cResult = cResult + CHAR_LF
                    nPos = nPos + 1
                but cEscaped = "r"
                    cResult = cResult + CHAR_CR
                    nPos = nPos + 1
                but cEscaped = "t"
                    cResult = cResult + CHAR_TAB
                    nPos = nPos + 1
                but cEscaped = CHAR_QUOTE
                    cResult = cResult + CHAR_QUOTE
                    nPos = nPos + 1
                but cEscaped = CHAR_BACKSLASH
                    cResult = cResult + CHAR_BACKSLASH
                    nPos = nPos + 1
                but cEscaped = CHAR_SLASH
                    cResult = cResult + CHAR_SLASH
                    nPos = nPos + 1
                but cEscaped = "b"
                    cResult = cResult + CHAR_BACKSPACE
                    nPos = nPos + 1
                but cEscaped = "f"
                    cResult = cResult + CHAR_FORMFEED
                    nPos = nPos + 1
                but cEscaped = "u"
                    # Unicode escape - use parseUnicodeEscape
                    nPos = nPos + 1   # Skip 'u'
                    cDecoded = parseUnicodeEscape()
                    if cError != ""
                        return ""
                    ok
                    cResult = cResult + cDecoded
                else
                    cError = "Invalid escape sequence '\\" + cEscaped + "' at position " + (nPos - 1)
                    return ""
                ok
            # Regular character
            else
                nCode = ascii(cChar)
                # Check for invalid control characters (0x00-0x1F)
                if nCode < 32
                    cError = "Invalid control character (code " + nCode + ") in string at position " + nPos
                    return ""
                ok
                cResult = cResult + cChar
                nPos = nPos + 1
            ok
        end
        
        cError = "Unterminated string"
        return ""
    
    ###########################################################################
    # Parse Unicode escape sequence (\uXXXX) with surrogate pair support
    # Call this AFTER consuming the "\u" prefix
    ###########################################################################
    func parseUnicodeEscape
        # Parse first 4 hex digits
        if nPos + 3 > nLength
            cError = "Incomplete unicode escape at position " + (nPos - 2)
            return ""
        ok
        
        cHex = substr(cJson, nPos, 4)
        if not isValidHex(cHex)
            cError = "Invalid unicode escape at position " + (nPos - 2)
            return ""
        ok
        
        nCode = hexToDecimal(cHex)
        nPos = nPos + 4
        
        # Check if this is a high surrogate (first half of surrogate pair)
        # High surrogates: U+D800 to U+DBFF (55296 to 56319)
        if nCode >= 55296 and nCode <= 56319
            
            # Expect \uXXXX for low surrogate
            if nPos + 5 <= nLength
                cNext1 = substr(cJson, nPos, 1)
                cNext2 = substr(cJson, nPos + 1, 1)
                
                if cNext1 = CHAR_BACKSLASH and cNext2 = "u"
                    nPos = nPos + 2   # Skip \u
                    
                    if nPos + 3 > nLength
                        cError = "Incomplete low surrogate at position " + (nPos - 2)
                        return ""
                    ok
                    
                    cHexLow = substr(cJson, nPos, 4)
                    if not isValidHex(cHexLow)
                        cError = "Invalid low surrogate at position " + (nPos - 2)
                        return ""
                    ok
                    
                    nLowCode = hexToDecimal(cHexLow)
                    nPos = nPos + 4
                    
                    # Verify it's a valid low surrogate (U+DC00 to U+DFFF)
                    # 0xDC00 = 56320, 0xDFFF = 57343
                    if nLowCode >= 56320 and nLowCode <= 57343
                        # Combine surrogate pair into full code point
                        # Formula: 0x10000 + ((high - 0xD800) * 0x400) + (low - 0xDC00)
                        nHighOffset = nCode - 55296
                        nLowOffset = nLowCode - 56320
                        nCode = 65536 + (nHighOffset * 1024) + nLowOffset
                    else
                        cError = "Invalid low surrogate value at position " + (nPos - 4)
                        return ""
                    ok
                else
                    # High surrogate without low surrogate - invalid
                    cError = "Missing low surrogate after high surrogate at position " + nPos
                    return ""
                ok
            else
                cError = "Missing low surrogate after high surrogate at position " + nPos
                return ""
            ok
        ok
        
        # Check for orphan low surrogate (error)
        # Low surrogates: U+DC00 to U+DFFF (56320 to 57343)
        if nCode >= 56320 and nCode <= 57343
            cError = "Unexpected low surrogate at position " + (nPos - 4)
            return ""
        ok
        
        # Encode the code point as UTF-8
        return encodeUTF8(nCode)
    
    ###########################################################################
    # Parse JSON Number
    ###########################################################################
    func parseNumber
        nStart = nPos
        
        # Handle negative sign
        if nPos <= nLength and substr(cJson, nPos, 1) = "-"
            nPos = nPos + 1
        ok
        
        # Must have at least one digit
        if nPos > nLength or not isDigit(substr(cJson, nPos, 1))
            cError = "Invalid number at position " + nStart
            return NULL
        ok
        
        # Integer part
        # Leading zero must be followed by . or end
        if substr(cJson, nPos, 1) = "0"
            nPos = nPos + 1
            if nPos <= nLength and isDigit(substr(cJson, nPos, 1))
                cError = "Leading zeros not allowed at position " + nStart
                return NULL
            ok
        else
            while nPos <= nLength and isDigit(substr(cJson, nPos, 1))
                nPos = nPos + 1
            end
        ok
        
        # Decimal part
        if nPos <= nLength and substr(cJson, nPos, 1) = "."
            nPos = nPos + 1
            
            # Must have at least one digit after decimal point
            if nPos > nLength or not isDigit(substr(cJson, nPos, 1))
                cError = "Invalid number: expected digit after decimal point at position " + nPos
                return NULL
            ok
            
            while nPos <= nLength and isDigit(substr(cJson, nPos, 1))
                nPos = nPos + 1
            end
        ok
        
        # Exponent part
        if nPos <= nLength
            cChar = substr(cJson, nPos, 1)
            if cChar = "e" or cChar = "E"
                nPos = nPos + 1
                
                # Optional sign
                if nPos <= nLength
                    cChar = substr(cJson, nPos, 1)
                    if cChar = "+" or cChar = "-"
                        nPos = nPos + 1
                    ok
                ok
                
                # Must have at least one digit in exponent
                if nPos > nLength or not isDigit(substr(cJson, nPos, 1))
                    cError = "Invalid number: expected digit in exponent at position " + nPos
                    return NULL
                ok
                
                while nPos <= nLength and isDigit(substr(cJson, nPos, 1))
                    nPos = nPos + 1
                end
            ok
        ok
        
        cNumStr = substr(cJson, nStart, nPos - nStart)
        # Guard against numeric overflow (e.g. 1e309): number() raises a
        # runtime error that would kill the host program.
        try
            nValue = number(cNumStr)
        catch
            cError = "Number out of range at position " + nStart
            return NULL
        done
        return nValue
    
    ###########################################################################
    # Parse true
    ###########################################################################
    func parseTrue
        if nPos + 3 <= nLength and substr(cJson, nPos, 4) = "true"
            nPos = nPos + 4
            return JSON_TRUE_SENTINEL
        ok
        cError = "Invalid literal at position " + nPos
        return NULL
    
    ###########################################################################
    # Parse false
    ###########################################################################
    func parseFalse
        if nPos + 4 <= nLength and substr(cJson, nPos, 5) = "false"
            nPos = nPos + 5
            return JSON_FALSE_SENTINEL
        ok
        cError = "Invalid literal at position " + nPos
        return NULL
    
    ###########################################################################
    # Parse null
    ###########################################################################
    func parseNull
        if nPos + 3 <= nLength and substr(cJson, nPos, 4) = "null"
            nPos = nPos + 4
            return NULL
        ok
        cError = "Invalid literal at position " + nPos
        return NULL
    
    ###########################################################################
    # Skip whitespace characters
    ###########################################################################
    func skipWhitespace
        while nPos <= nLength
            cChar = substr(cJson, nPos, 1)
            if cChar = CHAR_SPACE or cChar = CHAR_TAB or cChar = CHAR_LF or cChar = CHAR_CR
                nPos = nPos + 1
            else
                return
            ok
        end
    
    ###########################################################################
    # Check if string is valid hex (4 characters)
    ###########################################################################
    func isValidHex cHex
        if len(cHex) != 4
            return False
        ok
        for i = 1 to 4
            nCode = ascii(substr(cHex, i, 1))
            # Check if 0-9 (48-57) or A-F (65-70) or a-f (97-102)
            if not ((nCode >= 48 and nCode <= 57) or 
                    (nCode >= 65 and nCode <= 70) or 
                    (nCode >= 97 and nCode <= 102))
                return False
            ok
        next
        return True
    
    ###########################################################################
    # Convert 4-character hex string to decimal
    ###########################################################################
    func hexToDecimal cHex
        nResult = 0
        for i = 1 to 4
            c = substr(cHex, i, 1)
            nCode = ascii(c)
            
            # 0-9
            if nCode >= 48 and nCode <= 57
                nDigit = nCode - 48
            # A-F
            but nCode >= 65 and nCode <= 70
                nDigit = nCode - 55
            # a-f
            but nCode >= 97 and nCode <= 102
                nDigit = nCode - 87
            else
                nDigit = 0
            ok
            
            nResult = nResult * 16 + nDigit
        next
        return nResult
    
    ###########################################################################
    # Encode Unicode code point to UTF-8
    ###########################################################################
    func encodeUTF8 nCode
        if nCode < 128
            return char(nCode)
        ok
        if nCode < 2048
            nByte1 = 192 + floor(nCode / 64)
            nByte2 = 128 + (nCode % 64)
            return char(nByte1) + char(nByte2)
        ok
        if nCode < 65536
            nByte1 = 224 + floor(nCode / 4096)
            nByte2 = 128 + floor((nCode % 4096) / 64)
            nByte3 = 128 + (nCode % 64)
            return char(nByte1) + char(nByte2) + char(nByte3)
        ok
        # 4-byte UTF-8 for code points >= 65536 (emoji, etc.)
        nByte1 = 240 + floor(nCode / 262144)
        nByte2 = 128 + floor((nCode % 262144) / 4096)
        nByte3 = 128 + floor((nCode % 4096) / 64)
        nByte4 = 128 + (nCode % 64)
        return char(nByte1) + char(nByte2) + char(nByte3) + char(nByte4)

# ==============================================================================
# JSONGenerator Class - Converts Ring data structures to JSON strings
# ==============================================================================

class JSONGenerator
    
    nIndent     = 0
    bPretty     = False
    cIndentStr  = "  "
    cNewline    = CHAR_LF
    
    ###########################################################################
    # Generate JSON string (compact)
    ###########################################################################
    func toString xValue
        nIndent = 0
        bPretty = False
        return generate(xValue)
    
    ###########################################################################
    # Generate JSON string (pretty printed)
    ###########################################################################
    func toPrettyString xValue
        nIndent = 0
        bPretty = True
        return generate(xValue)
    
    ###########################################################################
    # Set indentation string
    ###########################################################################
    func setIndent cStr
        cIndentStr = cStr
        return self
    
    ###########################################################################
    # Set newline character(s)
    ###########################################################################
    func setNewline cStr
        cNewline = cStr
        return self
    
    ###########################################################################
    # Generate JSON from any value
    ###########################################################################
    func generate xValue
        # Handle JSON null (Ring NULL / empty string).
        # isNull() must come first: NULL is a STRING in Ring, and the
        # number 0 must NOT be treated as null.
        if isNull(xValue)
            return "null"
        ok
        
        # Handle different types
        cType = type(xValue)
        
        if cType = "STRING"
            # Boolean sentinels before generic strings
            if xValue = JSON_TRUE_SENTINEL
                return "true"
            ok
            if xValue = JSON_FALSE_SENTINEL
                return "false"
            ok
            return generateString(xValue)
        ok
        
        if cType = "NUMBER"
            return generateNumber(xValue)
        ok
        
        if cType = "LIST"
            return generateArray(xValue)
        ok
        
        if cType = "OBJECT"
            if classname(xValue) = "jsonobject"
                return generateObject(xValue)
            ok
        ok
        
        # Default to null
        return "null"
    
    ###########################################################################
    # Generate JSON string value (with full Unicode support)
    ###########################################################################
    func generateString cStr
        cResult = CHAR_QUOTE
        
        nLen = len(cStr)
        i = 1
        while i <= nLen
            cChar = substr(cStr, i, 1)
            nCode = ascii(cChar)
            
            # Escape special characters
            if cChar = CHAR_QUOTE
                cResult = cResult + CHAR_BACKSLASH + CHAR_QUOTE
            but cChar = CHAR_BACKSLASH
                cResult = cResult + CHAR_BACKSLASH + CHAR_BACKSLASH
            but nCode = 10    # Newline
                cResult = cResult + CHAR_BACKSLASH + "n"
            but nCode = 13    # Carriage return
                cResult = cResult + CHAR_BACKSLASH + "r"
            but nCode = 9     # Tab
                cResult = cResult + CHAR_BACKSLASH + "t"
            but nCode = 8     # Backspace
                cResult = cResult + CHAR_BACKSLASH + "b"
            but nCode = 12    # Form feed
                cResult = cResult + CHAR_BACKSLASH + "f"
            but nCode < 32    # Other control characters
                cResult = cResult + CHAR_BACKSLASH + "u" + padLeft(decToHex(nCode), 4, "0")
            else
                # Check for UTF-8 multi-byte sequences and encode as \uXXXX if needed
                if nCode >= 128
                    # Decode UTF-8 to get the code point
                    aDecoded = decodeUTF8Char(cStr, i)
                    nCodePoint = aDecoded[1]
                    nBytesUsed = aDecoded[2]
                    
                    if nCodePoint > 65535
                        # Need surrogate pair for code points > 0xFFFF
                        nCodePoint = nCodePoint - 65536
                        nHighSurrogate = 55296 + floor(nCodePoint / 1024)
                        nLowSurrogate = 56320 + (nCodePoint % 1024)
                        cResult = cResult + CHAR_BACKSLASH + "u" + padLeft(decToHex(nHighSurrogate), 4, "0")
                        cResult = cResult + CHAR_BACKSLASH + "u" + padLeft(decToHex(nLowSurrogate), 4, "0")
                    but nCodePoint > 0
                        cResult = cResult + CHAR_BACKSLASH + "u" + padLeft(decToHex(nCodePoint), 4, "0")
                    else
                        # Invalid UTF-8, output as-is
                        cResult = cResult + cChar
                    ok
                    
                    i = i + nBytesUsed
                    loop
                else
                    cResult = cResult + cChar
                ok
            ok
            i = i + 1
        end
        
        cResult = cResult + CHAR_QUOTE
        return cResult
    
    ###########################################################################
    # Decode a UTF-8 character starting at position nPos
    # Returns [nCodePoint, nBytesUsed]
    ###########################################################################
    func decodeUTF8Char cStr, nPos
        nLen = len(cStr)
        if nPos > nLen
            return [0, 0]
        ok
        
        nByte1 = ascii(substr(cStr, nPos, 1))
        
        # Single byte (ASCII)
        if nByte1 < 128
            return [nByte1, 1]
        ok
        
        # 2-byte sequence
        if nByte1 >= 192 and nByte1 < 224
            if nPos + 1 <= nLen
                nByte2 = ascii(substr(cStr, nPos + 1, 1))
                if nByte2 >= 128 and nByte2 < 192
                    nCodePoint = ((nByte1 - 192) * 64) + (nByte2 - 128)
                    return [nCodePoint, 2]
                ok
            ok
            return [0, 1]
        ok
        
        # 3-byte sequence
        if nByte1 >= 224 and nByte1 < 240
            if nPos + 2 <= nLen
                nByte2 = ascii(substr(cStr, nPos + 1, 1))
                nByte3 = ascii(substr(cStr, nPos + 2, 1))
                if (nByte2 >= 128 and nByte2 < 192) and (nByte3 >= 128 and nByte3 < 192)
                    nCodePoint = ((nByte1 - 224) * 4096) + ((nByte2 - 128) * 64) + (nByte3 - 128)
                    return [nCodePoint, 3]
                ok
            ok
            return [0, 1]
        ok
        
        # 4-byte sequence
        if nByte1 >= 240 and nByte1 < 248
            if nPos + 3 <= nLen
                nByte2 = ascii(substr(cStr, nPos + 1, 1))
                nByte3 = ascii(substr(cStr, nPos + 2, 1))
                nByte4 = ascii(substr(cStr, nPos + 3, 1))
                if (nByte2 >= 128 and nByte2 < 192) and 
                   (nByte3 >= 128 and nByte3 < 192) and 
                   (nByte4 >= 128 and nByte4 < 192)
                    nCodePoint = ((nByte1 - 240) * 262144) + ((nByte2 - 128) * 4096) + 
                                 ((nByte3 - 128) * 64) + (nByte4 - 128)
                    return [nCodePoint, 4]
                ok
            ok
            return [0, 1]
        ok
        
        return [0, 1]
    
    ###########################################################################
    # Convert decimal to hex string
    ###########################################################################
    func decToHex nNum
        if nNum = 0
            return "0"
        ok
        
        cResult = ""
        cHexChars = "0123456789abcdef"
        
        while nNum > 0
            nRemainder = nNum % 16
            cResult = substr(cHexChars, nRemainder + 1, 1) + cResult
            nNum = floor(nNum / 16)
        end
        
        return cResult
    
    ###########################################################################
    # Generate JSON number value
    ###########################################################################
    func generateNumber nNum
        # Ensure numeric
        nNum = 0 + nNum
        
        # Zero (Ring treats -0.0 as 0)
        if nNum = 0
            return "0"
        ok
        
        # decimals() is global state with no getter; probe the host program's
        # current setting so we can restore it before every return.
        nSavedDecimals = probeDecimals()
        
        # Integer fast path: exact integers within the double's exact-integer
        # range format cleanly with no decimal places.
        if floor(nNum) = nNum and fabs(nNum) < 9007199254740992
            decimals(0)
            cResult = "" + nNum
            decimals(nSavedDecimals)
            return cResult
        ok
        
        # Ring's number->string switches to e-notation for extreme magnitudes
        # and ignores decimals() there, producing a ~90-digit mantissa. Detect
        # that case and emit our own compact e-notation instead.
        decimals(1)
        cProbe = "" + nNum
        decimals(nSavedDecimals)
        if substr(cProbe, "e") > 0 or substr(cProbe, "E") > 0
            return formatENotation(nNum)
        ok
        
        # General case: find the shortest fixed-point representation that
        # round-trips exactly. Ring's default number->string truncates to 2
        # decimals, so we raise precision until the value parses back unchanged.
        for nDigits = 1 to 17
            decimals(nDigits)
            cStr = trimZeros("" + nNum)
            decimals(nSavedDecimals)
            if number(cStr) = nNum
                return cStr
            ok
        next
        
        # Extreme magnitude: fixed-point cannot represent the value (tiny
        # numbers format as all zeros). Emit e-notation instead.
        return formatENotation(nNum)
    
    ###########################################################################
    # Trim trailing zeros from the fractional part of a numeric string.
    # Handles both plain ("2.500" -> "2.5") and e-notation ("1.0e+3" -> "1e+3").
    ###########################################################################
    func trimZeros cStr
        nDot = substr(cStr, ".")
        if nDot = 0
            return cStr
        ok
        
        nE = substr(cStr, "e")
        if nE = 0
            nE = len(cStr) + 1
        ok
        
        # Trim trailing zeros in the fractional part (before any exponent)
        nEnd = nE - 1
        while nEnd > nDot and substr(cStr, nEnd, 1) = "0"
            nEnd = nEnd - 1
        end
        
        # If trimmed back to the decimal point, drop the point too
        if nEnd = nDot
            nEnd = nEnd - 1
        ok
        
        return substr(cStr, 1, nEnd) + substr(cStr, nE)
    
    ###########################################################################
    # Format a number in e-notation (used for extreme magnitudes where
    # fixed-point formatting collapses to zeros).
    ###########################################################################
    func formatENotation nNum
        xAbs = fabs(nNum)
        cSign = ""
        if nNum < 0
            cSign = "-"
        ok
        
        nExp = floor(log10(xAbs))
        # Split the scaling to avoid pow() overflow/underflow at extreme
        # exponents (denormals reach e-324, where pow(10, nExp) is 0).
        nHalf = floor(nExp / 2)
        xMant = (xAbs / pow(10, nHalf)) / pow(10, nExp - nHalf)   # in [1, 10)
        
        # Find the shortest mantissa that round-trips with this exponent
        cMant = ""
        nSavedDecimals = probeDecimals()
        
        for nDigits = 1 to 17
            decimals(nDigits)
            cTry = trimZeros("" + xMant)
            decimals(nSavedDecimals)
            if number(cTry + formatExponent(nExp)) = xAbs
                cMant = cTry
                exit
            ok
        next
        
        if cMant = ""
            decimals(17)
            cMant = trimZeros("" + xMant)
            decimals(nSavedDecimals)
        ok
        
        return cSign + cMant + formatExponent(nExp)
    
    ###########################################################################
    # Probe the current global decimals() setting. Ring has no getter, but
    # number->string zero-pads the fractional part to exactly the configured
    # width, so formatting 2.5 at the CURRENT setting and counting fractional
    # digits yields the setting without modifying it.
    ###########################################################################
    func probeDecimals
        cStr = "" + 2.5
        nDot = substr(cStr, ".")
        if nDot = 0
            return 0
        ok
        return len(cStr) - nDot
    
    ###########################################################################
    # Build the exponent suffix (e.g. "e+308" or "e-20")
    ###########################################################################
    func formatExponent nExp
        if nExp >= 0
            return "e+" + nExp
        ok
        return "e-" + (-nExp)
    
    ###########################################################################
    # Generate JSON array
    ###########################################################################
    func generateArray aArr
        if len(aArr) = 0
            return "[]"
        ok
        
        cResult = "["
        
        if bPretty
            cResult = cResult + cNewline
            nIndent = nIndent + 1
        ok
        
        for i = 1 to len(aArr)
            if bPretty
                cResult = cResult + getIndent()
            ok
            
            cResult = cResult + generate(aArr[i])
            
            if i < len(aArr)
                cResult = cResult + ","
            ok
            
            if bPretty
                cResult = cResult + cNewline
            ok
        next
        
        if bPretty
            nIndent = nIndent - 1
            cResult = cResult + getIndent()
        ok
        
        cResult = cResult + "]"
        return cResult
    
    ###########################################################################
    # Generate JSON object
    ###########################################################################
    func generateObject oObj
        if oObj.count() = 0
            return "{}"
        ok
        
        cResult = "{"
        
        if bPretty
            cResult = cResult + cNewline
            nIndent = nIndent + 1
        ok
        
        aKeys = oObj.keys()
        nCount = len(aKeys)
        
        for i = 1 to nCount
            if bPretty
                cResult = cResult + getIndent()
            ok
            
            cKey = aKeys[i]
            xValue = oObj.getValue(cKey)
            
            cResult = cResult + generateString(cKey)
            cResult = cResult + ":"
            
            if bPretty
                cResult = cResult + " "
            ok
            
            cResult = cResult + generate(xValue)
            
            if i < nCount
                cResult = cResult + ","
            ok
            
            if bPretty
                cResult = cResult + cNewline
            ok
        next
        
        if bPretty
            nIndent = nIndent - 1
            cResult = cResult + getIndent()
        ok
        
        cResult = cResult + "}"
        return cResult
    
    ###########################################################################
    # Get current indentation string
    ###########################################################################
    func getIndent
        cResult = ""
        for i = 1 to nIndent
            cResult = cResult + cIndentStr
        next
        return cResult
    
    ###########################################################################
    # Pad string on left
    ###########################################################################
    func padLeft cStr, nLength, cPadChar
        while len(cStr) < nLength
            cStr = cPadChar + cStr
        end
        return cStr

# ==============================================================================
# JSONPath Class - Query JSON data using path expressions
# ==============================================================================

class JSONPath
    
    ###########################################################################
    # Get value at path (e.g., "users.0.name" or "config.settings.theme")
    ###########################################################################
    func getValue xData, cPath
        if cPath = "" or cPath = NULL
            return xData
        ok
        
        aParts = splitPath(cPath)
        xCurrent = xData
        
        for i = 1 to len(aParts)
            cPart = aParts[i]
            
            if isNull(xCurrent)
                return NULL
            ok
            
            cType = type(xCurrent)
            
            # Handle array access
            if cType = "LIST"
                if isNumeric(cPart)
                    nIndex = number(cPart) + 1   # Convert 0-based to 1-based
                    if nIndex >= 1 and nIndex <= len(xCurrent)
                        xCurrent = xCurrent[nIndex]
                    else
                        return NULL
                    ok
                else
                    return NULL
                ok
            # Handle object access
            but cType = "OBJECT" and classname(xCurrent) = "jsonobject"
                xCurrent = xCurrent.getValue(cPart)
            else
                return NULL
            ok
        next
        
        return xCurrent
    
    ###########################################################################
    # Set value at path
    ###########################################################################
    func set xData, cPath, xValue
        if cPath = "" or cPath = NULL
            return xValue
        ok
        
        aParts = splitPath(cPath)
        return setRecursive(xData, aParts, 1, xValue)
    
    ###########################################################################
    # Delete value at path
    ###########################################################################
    func delete xData, cPath
        if cPath = "" or cPath = NULL
            return xData
        ok
        
        aParts = splitPath(cPath)
        if len(aParts) = 0
            return xData
        ok
        
        # Navigate to parent
        if len(aParts) = 1
            xParent = xData
        else
            cParentPath = ""
            for i = 1 to len(aParts) - 1
                if i > 1
                    cParentPath = cParentPath + "."
                ok
                cParentPath = cParentPath + aParts[i]
            next
            xParent = getValue(xData, cParentPath)
        ok
        
        if isNull(xParent)
            return xData
        ok
        
        cLastPart = aParts[len(aParts)]
        
        if type(xParent) = "LIST"
            if isNumeric(cLastPart)
                nIndex = number(cLastPart) + 1
                if nIndex >= 1 and nIndex <= len(xParent)
                    del(xParent, nIndex)
                ok
            ok
        but type(xParent) = "OBJECT" and classname(xParent) = "jsonobject"
            xParent.remove(cLastPart)
        ok
        
        return xData
    
    ###########################################################################
    # Check if path exists
    ###########################################################################
    func exists xData, cPath
        # Navigate to the parent and check membership, so that keys whose
        # value is JSON null still report as existing.
        if cPath = "" or cPath = NULL
            return True
        ok
        
        aParts = splitPath(cPath)
        if len(aParts) = 0
            return True
        ok
        
        # Navigate to parent of the last part
        if len(aParts) = 1
            xParent = xData
        else
            cParentPath = ""
            for i = 1 to len(aParts) - 1
                if i > 1
                    cParentPath = cParentPath + "."
                ok
                cParentPath = cParentPath + aParts[i]
            next
            xParent = getValue(xData, cParentPath)
        ok
        
        if isNull(xParent)
            return False
        ok
        
        cLastPart = aParts[len(aParts)]
        
        if type(xParent) = "LIST"
            if isNumeric(cLastPart)
                nIndex = number(cLastPart) + 1
                return nIndex >= 1 and nIndex <= len(xParent)
            ok
            return False
        but type(xParent) = "OBJECT" and classname(xParent) = "jsonobject"
            return xParent.hasKey(cLastPart)
        ok
        
        return False
    
    ###########################################################################
    # Recursive set helper
    ###########################################################################
    func setRecursive xCurrent, aParts, nIndex, xValue
        if nIndex > len(aParts)
            return xValue
        ok
        
        cPart = aParts[nIndex]
        
        # Last part - set the value
        if nIndex = len(aParts)
            if type(xCurrent) = "LIST"
                if isNumeric(cPart)
                    nIdx = number(cPart) + 1
                    if nIdx >= 1 and nIdx <= len(xCurrent)
                        xCurrent[nIdx] = xValue
                    but nIdx = len(xCurrent) + 1
                        add(xCurrent, xValue)
                    ok
                ok
            but type(xCurrent) = "OBJECT" and classname(xCurrent) = "jsonobject"
                xCurrent.set(cPart, xValue)
            ok
            return xCurrent
        ok
        
        # Not last part - recurse
        if type(xCurrent) = "LIST"
            if isNumeric(cPart)
                nIdx = number(cPart) + 1
                if nIdx >= 1 and nIdx <= len(xCurrent)
                    xCurrent[nIdx] = setRecursive(xCurrent[nIdx], aParts, nIndex + 1, xValue)
                ok
            ok
        but type(xCurrent) = "OBJECT" and classname(xCurrent) = "jsonobject"
            xChild = xCurrent.getValue(cPart)
            if isNull(xChild)
                # Create intermediate structure
                cNextPart = aParts[nIndex + 1]
                if isNumeric(cNextPart)
                    xChild = []
                else
                    xChild = new JSONObject
                ok
            ok
            xCurrent.set(cPart, setRecursive(xChild, aParts, nIndex + 1, xValue))
        ok
        
        return xCurrent
    
    ###########################################################################
    # Split path into parts
    ###########################################################################
    func splitPath cPath
        aResult = []
        cCurrent = ""
        
        for i = 1 to len(cPath)
            c = substr(cPath, i, 1)
            if c = "." or c = "["
                if cCurrent != ""
                    add(aResult, cCurrent)
                    cCurrent = ""
                ok
            but c = "]"
                if cCurrent != ""
                    add(aResult, cCurrent)
                    cCurrent = ""
                ok
            else
                cCurrent = cCurrent + c
            ok
        next
        
        if cCurrent != ""
            add(aResult, cCurrent)
        ok
        
        return aResult
    
    ###########################################################################
    # Check if string is numeric
    ###########################################################################
    func isNumeric cStr
        if len(cStr) = 0
            return False
        ok
        for i = 1 to len(cStr)
            c = substr(cStr, i, 1)
            if c < "0" or c > "9"
                return False
            ok
        next
        return True

# ==============================================================================
# JSONQuery Class - Advanced querying with filters
# ==============================================================================

class JSONQuery
    
    ###########################################################################
    # Find all values matching a simple pattern
    # Pattern: "*.name" matches all "name" properties at any level
    ###########################################################################
    func findAll xData, cPattern
        aResults = []
        findAllRecursive(xData, cPattern, "", aResults)
        return aResults
    
    ###########################################################################
    # Recursive helper for findAll
    ###########################################################################
    func findAllRecursive xData, cPattern, cCurrentPath, aResults
        if isNull(xData)
            return
        ok
        
        cType = type(xData)
        
        if cType = "OBJECT" and classname(xData) = "jsonobject"
            aKeys = xData.keys()
            for i = 1 to len(aKeys)
                cKey = aKeys[i]
                if cCurrentPath = ""
                    cNewPath = cKey
                else
                    cNewPath = cCurrentPath + "." + cKey
                ok
                
                if matchPattern(cNewPath, cPattern)
                    add(aResults, [cNewPath, xData.getValue(cKey)])
                ok
                
                findAllRecursive(xData.getValue(cKey), cPattern, cNewPath, aResults)
            next
        but cType = "LIST"
            for i = 1 to len(xData)
                if cCurrentPath = ""
                    cNewPath = "" + (i - 1)
                else
                    cNewPath = cCurrentPath + "." + (i - 1)
                ok
                
                if matchPattern(cNewPath, cPattern)
                    add(aResults, [cNewPath, xData[i]])
                ok
                
                findAllRecursive(xData[i], cPattern, cNewPath, aResults)
            next
        ok
    
    ###########################################################################
    # Simple pattern matching
    # Supports * as wildcard for any single path segment
    ###########################################################################
    func matchPattern cPath, cPattern
        aPathParts = splitByDot(cPath)
        aPatternParts = splitByDot(cPattern)
        
        if len(aPathParts) != len(aPatternParts)
            return False
        ok
        
        for i = 1 to len(aPathParts)
            if aPatternParts[i] != "*" and aPatternParts[i] != aPathParts[i]
                return False
            ok
        next
        
        return True
    
    ###########################################################################
    # Split string by dot
    ###########################################################################
    func splitByDot cStr
        aResult = []
        cCurrent = ""
        
        for i = 1 to len(cStr)
            c = substr(cStr, i, 1)
            if c = "."
                add(aResult, cCurrent)
                cCurrent = ""
            else
                cCurrent = cCurrent + c
            ok
        next
        
        if cCurrent != ""
            add(aResult, cCurrent)
        ok
        
        return aResult
    
    ###########################################################################
    # Filter array by property value
    ###########################################################################
    func filterByProperty aArr, cProperty, xValue
        aResults = []
        oPath = new JSONPath
        
        for i = 1 to len(aArr)
            xItem = aArr[i]
            xItemValue = oPath.getValue(xItem, cProperty)
            if xItemValue = xValue
                add(aResults, xItem)
            ok
        next
        
        return aResults
    
    ###########################################################################
    # Sort array by property
    ###########################################################################
    func sortByProperty aArr, cProperty, bAscending
        if len(aArr) <= 1
            return aArr
        ok
        
        oPath = new JSONPath
        
        # Bubble sort (simple but works for small arrays)
        aResult = []
        for i = 1 to len(aArr)
            add(aResult, aArr[i])
        next
        
        for i = 1 to len(aResult) - 1
            for j = 1 to len(aResult) - i
                xVal1 = oPath.getValue(aResult[j], cProperty)
                xVal2 = oPath.getValue(aResult[j + 1], cProperty)
                
                bSwap = False
                if bAscending
                    if xVal1 > xVal2
                        bSwap = True
                    ok
                else
                    if xVal1 < xVal2
                        bSwap = True
                    ok
                ok
                
                if bSwap
                    xTemp = aResult[j]
                    aResult[j] = aResult[j + 1]
                    aResult[j + 1] = xTemp
                ok
            next
        next
        
        return aResult

# ==============================================================================
# JSONSchema Class - Basic JSON Schema validation
# ==============================================================================

class JSONSchema
    
    aErrors = []
    
    ###########################################################################
    # Validate data against schema
    ###########################################################################
    func validate xData, xSchema
        aErrors = []
        validateValue(xData, xSchema, "")
        return len(aErrors) = 0
    
    ###########################################################################
    # Get validation errors
    ###########################################################################
    func getErrors
        return aErrors
    
    ###########################################################################
    # Validate a value against schema
    ###########################################################################
    func validateValue xData, xSchema, cPath
        if type(xSchema) != "OBJECT" or classname(xSchema) != "jsonobject"
            return
        ok
        
        # Check type
        cSchemaType = xSchema.getValue("type")
        if not isNull(cSchemaType)
            if not validateType(xData, cSchemaType)
                addError(cPath, "Expected type '" + cSchemaType + "'")
                return
            ok
        ok
        
        # String validations
        if cSchemaType = "string"
            validateString(xData, xSchema, cPath)
        ok
        
        # Number validations
        if cSchemaType = "number" or cSchemaType = "integer"
            validateNumber(xData, xSchema, cPath)
        ok
        
        # Array validations
        if cSchemaType = "array"
            validateArray(xData, xSchema, cPath)
        ok
        
        # Object validations
        if cSchemaType = "object"
            validateObject(xData, xSchema, cPath)
        ok
    
    ###########################################################################
    # Validate type
    ###########################################################################
    func validateType xData, cSchemaType
        if cSchemaType = "string"
            # Exclude boolean sentinels and null
            return type(xData) = "STRING" and not isNull(xData) and
                   xData != JSON_TRUE_SENTINEL and xData != JSON_FALSE_SENTINEL
        ok
        if cSchemaType = "number"
            return type(xData) = "NUMBER"
        ok
        if cSchemaType = "integer"
            if type(xData) != "NUMBER"
                return False
            ok
            return floor(xData) = xData
        ok
        if cSchemaType = "boolean"
            return json_is_boolean(xData)
        ok
        if cSchemaType = "array"
            return type(xData) = "LIST"
        ok
        if cSchemaType = "object"
            return type(xData) = "OBJECT" and classname(xData) = "jsonobject"
        ok
        if cSchemaType = "null"
            return isNull(xData)
        ok
        return True
    
    ###########################################################################
    # Validate string
    ###########################################################################
    func validateString cData, xSchema, cPath
        nMinLength = xSchema.getValue("minLength")
        if not isNull(nMinLength) and len(cData) < nMinLength
            addError(cPath, "String length must be at least " + nMinLength)
        ok
        
        nMaxLength = xSchema.getValue("maxLength")
        if not isNull(nMaxLength) and len(cData) > nMaxLength
            addError(cPath, "String length must be at most " + nMaxLength)
        ok
        
        cPattern = xSchema.getValue("pattern")
        if not isNull(cPattern)
            # Note: Full regex not supported, just basic contains check
            # addError(cPath, "Pattern validation not fully supported")
        ok
    
    ###########################################################################
    # Validate number
    ###########################################################################
    func validateNumber nData, xSchema, cPath
        nMinimum = xSchema.getValue("minimum")
        if not isNull(nMinimum) and nData < nMinimum
            addError(cPath, "Value must be at least " + nMinimum)
        ok
        
        nMaximum = xSchema.getValue("maximum")
        if not isNull(nMaximum) and nData > nMaximum
            addError(cPath, "Value must be at most " + nMaximum)
        ok
        
        nExclusiveMinimum = xSchema.getValue("exclusiveMinimum")
        if not isNull(nExclusiveMinimum) and nData <= nExclusiveMinimum
            addError(cPath, "Value must be greater than " + nExclusiveMinimum)
        ok
        
        nExclusiveMaximum = xSchema.getValue("exclusiveMaximum")
        if not isNull(nExclusiveMaximum) and nData >= nExclusiveMaximum
            addError(cPath, "Value must be less than " + nExclusiveMaximum)
        ok
    
    ###########################################################################
    # Validate array
    ###########################################################################
    func validateArray aData, xSchema, cPath
        nMinItems = xSchema.getValue("minItems")
        if not isNull(nMinItems) and len(aData) < nMinItems
            addError(cPath, "Array must have at least " + nMinItems + " items")
        ok
        
        nMaxItems = xSchema.getValue("maxItems")
        if not isNull(nMaxItems) and len(aData) > nMaxItems
            addError(cPath, "Array must have at most " + nMaxItems + " items")
        ok
        
        xItems = xSchema.getValue("items")
        if not isNull(xItems)
            for i = 1 to len(aData)
                if cPath = ""
                    cItemPath = "" + (i - 1)
                else
                    cItemPath = cPath + "[" + (i - 1) + "]"
                ok
                validateValue(aData[i], xItems, cItemPath)
            next
        ok
    
    ###########################################################################
    # Validate object
    ###########################################################################
    func validateObject oData, xSchema, cPath
        xProperties = xSchema.getValue("properties")
        aRequired = xSchema.getValue("required")
        
        # Check required properties
        if not isNull(aRequired) and type(aRequired) = "LIST"
            for i = 1 to len(aRequired)
                cProp = aRequired[i]
                if not oData.hasKey(cProp)
                    if cPath = ""
                        cPropPath = cProp
                    else
                        cPropPath = cPath + "." + cProp
                    ok
                    addError(cPropPath, "Required property missing")
                ok
            next
        ok
        
        # Validate properties
        if not isNull(xProperties) and type(xProperties) = "OBJECT" and classname(xProperties) = "jsonobject"
            aKeys = oData.keys()
            for i = 1 to len(aKeys)
                cKey = aKeys[i]
                xPropSchema = xProperties.getValue(cKey)
                if not isNull(xPropSchema)
                    if cPath = ""
                        cPropPath = cKey
                    else
                        cPropPath = cPath + "." + cKey
                    ok
                    validateValue(oData.getValue(cKey), xPropSchema, cPropPath)
                ok
            next
        ok
    
    ###########################################################################
    # Add error to list
    ###########################################################################
    func addError cPath, cMessage
        if cPath = ""
            cFullMessage = cMessage
        else
            cFullMessage = cPath + ": " + cMessage
        ok
        add(aErrors, cFullMessage)