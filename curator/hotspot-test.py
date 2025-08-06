import os
import sys

class HotspotTest:
    def __init__(self, hotspotData, hotspotIdList, verbose=False):
        self.idResults = None
        self.nameResults = None
        self.descriptionResults = None
        self.assetResults = None
        self.locationResults = None
        self.hotspotData = hotspotData
        self.hotspotIdList = hotspotIdList
        self.verbose = verbose
    
    def printResults(self):
        if not self.verbose:
            if not self.idResults:
                print(f"Hotspot ID {self.hotspotData.get('hotspotId')} failed the ID test.")
            if not self.nameResults:
                print(f"Hotspot {self.hotspotData.get('hotspotId')} failed the name test.") 
            if not self.assetResults:
                print(f"Hotspot {self.hotspotData.get('hotspotId')} failed the assets test.")
            if not self.locationResults:
                print(f"Hotspot {self.hotspotData.get('hotspotId')} failed the location test.")
            return

        print(f"Id Test Passed: {self.idResults}")
        print(f"Name Test Passed: {self.nameResults}")
        print(f"Assets Test Passed: {self.assetResults}")
        print(f"Location Test Passed: {self.locationResults}")

    def assertJson(self, hotspotData): # This function checks if the required keys are present in the hotspot JSON data. If they are they are added to the return array.
        requiredKeys = ['hotspotId', 'name', 'description', 'location', 'createdOn', 'status', 'features']
        returnArray = []
        for key in requiredKeys:
            if key in self.hotspotData:
                returnArray.append(key)
        return returnArray
    
    def testHotspotId(self, hostpotIdList): # tests the hotspotID to see if it is unique. If it is not unique, it returns false, otherwise it adds the hotspotId to the list and returns None.
        if self.hotspotData.get('hotspotId') in hostpotIdList:
            print(f"Hotspot ID {self.hotspotData.get('hotspotId')} already exists.")
            return False
        else:
            hostpotIdList.append(self.hotspotData.get('hotspotId'))
            print(f"Hotspot ID {self.hotspotData.get('hotspotId')} is unique.")
        return True

    def testName(self):
        # this is where we would test the naming format, max char length etc for flutter. Name can be the same it doesnt really matter.
        return True

    def testDescription(self):
        # same deal as name, we would test the description format, max char length etc for flutter.
        return True

    def testAssets(self):  # This function checks if the assets in the hotspot JSON are present in the filesystem and if they are in the correct format (image, text, video, audio). It returns None if all assets are valid, otherwise it prints an error message and returns false.
        for asset in self.hotspotData.get('features', []):
            assetPath = f"{os.path.dirname(__file__)}\\hotspots\\{self.hotspotData.get('hotspotId')}\\Assets\\{asset.get('fileLocation')}"
            if not os.path.exists(assetPath):
                print(f"Asset file not found: {assetPath}")
                return False
            fileType = checkSupportedFormats(asset.get('fileLocation'))
            if fileType != asset.get('type'):
                print(f"Asset file {asset.get('fileLocation')} is not in the correct format, expected {asset.get('type')}, found {fileType}.")
                return False
            return True
    
    def testLocation(self):
        loc = self.hotspotData.get('location', {})
        if loc.get('latitude') > 90 or loc.get('latitude') < -90:
            print(f"Invalid latitude: {loc.get('latitude')}")
            return False
        if loc.get('longitude') > 180 or loc.get('longitude') < -180:
            print(f"Invalid longitude: {loc.get('longitude')}")
            return False    
        return True
    
    def runTests(self):
        jsonSuccess = True
        self.idResults = self.testHotspotId(self.hotspotIdList)
        if not self.idResults:
            jsonSuccess = False
        self.nameResults = self.testName()
        if not self.nameResults:
            jsonSuccess = False
        self.assetResults = self.testAssets()
        if not self.assetResults:
            jsonSuccess = False
        self.locationResults = self.testLocation()
        if not self.locationResults:
            jsonSuccess = False
        
        if jsonSuccess:
            print(f"All tests passed for hotspot {self.hotspotData.get('hotspotId')}.")
        else:
            print(f"Some tests failed for hotspot {self.hotspotData.get('hotspotId')}.")
        
        return jsonSuccess

def checkSupportedFormats(fileName): # This function checks the file extension of the asset and returns the type of file it is. This is mainly to make sure the extensions are right, obviously they can just be renamed. 
    imageFormats = ['.png', '.jpg', '.jpeg', '.gif', '.tiff', '.bmp', '.dib', '.webp', '.heif', '.heifs', '.heic', '.heics', '.avci', '.avcs', '.HIF']
    textFormats = ['.txt', '.md', '.json', '.xml']
    if fileName.endswith(tuple(imageFormats)):
        return 'image'
    elif fileName.endswith(tuple(textFormats)):
        return 'text'
    elif fileName.endswith(tuple(['.mp4', '.mov'])):
        return 'video'
    elif fileName.endswith(tuple(['.mp3', '.wav', '.flac'])):
        return 'audio'
    return 'false'

def getHotspots(): # returns a list of hostpots found in the hotspots directory.
    listOfHotspots = []
    for dir in os.listdir(f"{os.path.dirname(__file__)}\\hotspots"):
        listOfHotspots.append(dir)
    return listOfHotspots

def main():
    hotspotIdList = []
    hotspots = getHotspots()
    print(f"Found {len(hotspots)} hotspots to test.")
    for hotspot in hotspots:
        jsonSuccess = True
        print(f"Testing hotspot: {hotspot}")
        jsonFile = f"{os.path.dirname(__file__)}\\hotspots\\{hotspot}\\hotspot.json"
        if not os.path.exists(jsonFile):
            print(f"Hotspot JSON file not found: {jsonFile}")
            continue
        with open(jsonFile, 'r') as file:
            hotspotData = file.read()   
        try:
            hotspotData = eval(hotspotData)
        except Exception as e:
            print(f"Error parsing JSON for hotspot {hotspot}: {e}")
            jsonSuccess = False
            continue
        if jsonSuccess:
            hotspotTest = HotspotTest(hotspotData, hotspotIdList)
            results = hotspotTest.runTests()
            hotspotTest.printResults()

        


    print("All tests completed.")

if __name__ == "__main__":
    main()
    sys.exit(0)