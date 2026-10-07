# App screenshots

Real captures from FastLog running on an iPhone 16 Pro simulator with iOS 18.6, taken October 7, 2026. Images are 1206 × 2622 pixels. The simulator status bar is set to 9:41; the captures are otherwise unedited.

## Dashboard

[dashboard.png](dashboard.png) shows the **Today** screen with a 2,300-calorie target, 1,330 calories logged, macro progress, and micronutrient totals. The sample account has three food logs, two saved meals, and four weight entries, created through the local API.

## Manual log

[manual-log.png](manual-log.png) shows **Log Food** with a chicken-and-rice dinner entered: 620 calories, 48g protein, 71g carbs, and 16g fat. This form was captured before submission, with the keyboard dismissed.

## Saved meals

[saved-meals.png](saved-meals.png) shows two templates, their macros, aliases, and **Log** buttons. “Greek yogurt & oats” has the alias “usual breakfast,” matching the README walkthrough.

## Capture setup

The app ran in [developer mode](../../ios/README.md#local-development-developer-mode) against the current repository's memory backend. Sample food logs use the default `manual` source; these screenshots do not depict a live ChatGPT Action call.

Full Xcode was unavailable, so these captures used an existing local simulator build dated June 12, 2026. The only subsequent change to `ios/FastLog/` is the default backend URL, which was overridden in developer mode. A fresh build of the current source was not performed.
