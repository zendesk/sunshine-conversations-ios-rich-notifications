# Installation Instructions

Before following the steps below, make sure that the [smooch-ios](https://github.com/smooch/smooch-ios) framework is installed in your application, and that you are on at least version 5.0.0.

## Create the extension

1. In Xcode, create a new extension target for your project (File > New > Target)
2. Select "Notification Content" as the target type
3. Give your extension a name and click "Finish"

## Configure your extension

1. In Xcode, find the directory associated to your target and open the info.plist file
2. Under the "NSExtension" field, remove the `NSExtensionMainStoryboard` key
3. Add a new String value under "NSExtension" with the key `NSExtensionPrincipalClass` and value `SKTRichNotificationViewController`
4. Add a new Boolean value under "NSExtension > NSExtensionAttributes"  with the key `UNNotificationExtensionDefaultContentHidden` and the value `YES`
5. Change the value of "NSExtension > NSExtensionAttributes > UNNotificationExtensionCategory" to `SmoochReplyableNotification`

Once complete, your info.plist file should look like this:

![Info.plist configuration](https://raw.githubusercontent.com/smooch/smooch-ios-rich-notifications/master/readme_img/info-plist.png)

## Include the source and assets

1. In Xcode, find the directory associated to your target
2. Delete the generated `MainInterface.storyboard`, `NotificationViewController.h`, and `NotificationViewController.m` files
3. Drag the contents of the `src` and `assets` directories into the folder, and make sure your extension target is selected under the "Add to targets" field

Your extension folder should look like this when finished:

![Extension folder structure](https://raw.githubusercontent.com/smooch/smooch-ios-rich-notifications/master/readme_img/config.png)

That's it! Build and run your application, and Smooch push notifications should now render the conversation history when viewed.