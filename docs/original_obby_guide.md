# RollboxGame

A beginner guide to creating a Roblox game in Roblox Studio and keeping its files on GitHub.

This repository currently contains instructions. Follow the steps below to build a small obstacle course (obby) called **RollboxGame**.

## 1. Set up Roblox Studio

1. Create or sign in to your Roblox account.
2. Install [Roblox Studio](https://create.roblox.com/).
3. Open Studio, sign in, and create a new **Baseplate** project.
4. Open the **Explorer**, **Properties**, and **Output** panels so you can inspect objects, edit their properties, and see script errors.

## 2. Build the obstacle course

1. Keep or add a **SpawnLocation** on the starting platform.
2. Insert several **Part** objects to make platforms. Use the Move and Scale tools to arrange them into a short jumping course.
3. Set each platform's **Anchored** property to `true` so it stays in place. Keep **CanCollide** enabled.
4. Make the first jumps easy, then gradually increase the distance between platforms.
5. Add a large red Part below the course. Name it `Lava`, anchor it, and make it wide enough to catch falling players.
6. Add a green platform at the end and name it `Finish`.

## 3. Add a lava hazard

In Explorer, insert a regular **Script** inside `Lava` and replace its contents with:

```lua
local lava = script.Parent

lava.Touched:Connect(function(hit)
    local character = hit:FindFirstAncestorOfClass("Model")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if humanoid then
        humanoid.Health = 0
    end
end)
```

Touching the lava defeats the character, which then respawns at the spawn point.

## 4. Track completion

Insert a regular **Script** in **ServerScriptService** and paste:

```lua
local Players = game:GetService("Players")
local finish = workspace:WaitForChild("Finish")

Players.PlayerAdded:Connect(function(player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player

    local completed = Instance.new("BoolValue")
    completed.Name = "Completed"
    completed.Value = false
    completed.Parent = leaderstats
end)

finish.Touched:Connect(function(hit)
    local character = hit:FindFirstAncestorOfClass("Model")
    local player = character and Players:GetPlayerFromCharacter(character)
    local leaderstats = player and player:FindFirstChild("leaderstats")
    local completed = leaderstats and leaderstats:FindFirstChild("Completed")

    if completed then
        completed.Value = true
    end
end)
```

The player list shows completion when a player reaches `Finish`. This value lasts for the current server session; saving progress between sessions requires a separate DataStore implementation.

## 5. Test the game

1. Start a Studio playtest with **F5**.
2. Check that the player spawns on the starting platform and can finish every jump.
3. Touch the lava and confirm that the character respawns.
4. Reach the finish platform and check the `Completed` value in the player list.
5. Stop the test before editing. Check Output for errors.
6. Use Studio's server/client testing tools with two players to verify that completion is tracked separately for each player.

## 6. Save the project to this repository

1. Use Studio's local save option to save your place as `RollboxGame.rbxl` inside your local repository folder. You can use `.rbxlx` instead if you prefer Roblox's XML place format.
2. Optionally keep copies of your scripts as `.luau` files under `src/` for easier code review. These copies do not automatically synchronize with Studio; keep them consistent manually or set up a dedicated sync workflow later.
3. From PowerShell in the repository folder, commit the files you saved:

```powershell
git status
git add RollboxGame.rbxl
git commit -m "Add initial Roblox obstacle course"
git push
```

If you saved an XML place, replace `RollboxGame.rbxl` with `RollboxGame.rbxlx`. Add `src/` separately if you created it. Never commit account passwords, authentication tokens, or other secrets.

## 7. Publish to Roblox

1. In Roblox Studio, use **File > Publish** (the command may also be labeled **Publish to Roblox**).
2. Create an experience named **RollboxGame**, choose its owner, and add a description.
3. Publish the starting place, then find the experience in [Creator Hub](https://create.roblox.com/).
4. Keep access private while testing. Before public release, complete the audience, content maturity, and publishing requirements shown by Roblox for your account.
5. When ready, enable public access using the experience's publishing/access settings.
6. Test the published experience in the Roblox app. Publish later Studio changes to update it.

Pushing to GitHub backs up project files. Publishing from Studio uploads the playable experience to Roblox. Both steps are needed if you want a GitHub copy and a playable Roblox release.

## Official documentation

- [Roblox projects and Studio](https://create.roblox.com/docs/projects)
- [Studio testing modes](https://create.roblox.com/docs/studio/testing-modes)
- [Create and publish games and places](https://create.roblox.com/docs/production/publishing/publish-games-and-places)
- [Roblox publishing guidance](https://en.help.roblox.com/hc/en-us/articles/203313890-How-to-Publish-Games-on-Roblox)
