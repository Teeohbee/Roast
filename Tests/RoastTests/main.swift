@testable import RoastKit

ModelsTests.run()
PreferencesStoreTests.run()
PRStoreTests.run()
PRStoreTests.runDiffTests()
GitHubClientTests.run()
NotificationManagerTests.run()
ReviewCommandTests.run()
MergedPRTests.run()
PollFailureTests.run()
LogFileTests.run()
FetchPRsTests.run()

reportResults()
