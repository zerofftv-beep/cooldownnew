#!/bin/bash

# Создание структуры папок
mkdir -p src/main/java/me/combat
mkdir -p src/main/resources
mkdir -p .github/workflows

# Создание pom.xml
cat <<EOF > pom.xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>me.combat</groupId>
    <artifactId>CombatCooldown</artifactId>
    <version>1.0-SNAPSHOT</version>
    <packaging>jar</packaging>
    <properties>
        <java.version>17</java.version>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.8.1</version>
                <configuration>
                    <source>\${java.version}</source>
                    <target>\${java.version}</target>
                </configuration>
            </plugin>
        </plugins>
    </build>
    <repositories>
        <repository>
            <id>spigotmc-repo</id>
            <url>https://hub.spigotmc.org/nexus/content/repositories/snapshots/</url>
        </repository>
    </repositories>
    <dependencies>
        <dependency>
            <groupId>org.spigotmc</groupId>
            <artifactId>spigot-api</artifactId>
            <version>1.20.1-R0.1-SNAPSHOT</version>
            <scope>provided</scope>
        </dependency>
    </dependencies>
</project>
EOF

# Создание plugin.yml
cat <<EOF > src/main/resources/plugin.yml
name: CombatCooldown
version: 1.0-SNAPSHOT
main: me.combat.CombatPlugin
api-version: 1.20
author: Assistant
description: Prevents command usage and logging out during combat.
EOF

# Создание CombatPlugin.java
cat <<EOF > src/main/java/me/combat/CombatPlugin.java
package me.combat;
import org.bukkit.plugin.java.JavaPlugin;
import org.bukkit.scheduler.BukkitRunnable;
public class CombatPlugin extends JavaPlugin {
    private CombatManager combatManager;
    @Override
    public void onEnable() {
        this.combatManager = new CombatManager(this);
        getServer().getPluginManager().registerEvents(new CombatListener(combatManager), this);
        new BukkitRunnable() {
            @Override
            public void run() {
                combatManager.updateTimers();
            }
        }.runTaskTimer(this, 0L, 20L);
        getLogger().info("CombatCooldown plugin enabled!");
    }
}
EOF

# Создание CombatManager.java
cat <<EOF > src/main/java/me/combat/CombatManager.java
package me.combat;
import org.bukkit.Bukkit;
import org.bukkit.boss.BarColor;
import org.bukkit.boss.BarStyle;
import org.bukkit.boss.BossBar;
import org.bukkit.entity.Player;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
public class CombatManager {
    private final CombatPlugin plugin;
    private final Map<UUID, Long> combatTimers = new ConcurrentHashMap<>();
    private final Map<UUID, BossBar> bossBars = new ConcurrentHashMap<>();
    private final long COMBAT_DURATION = 30 * 1000L;
    public CombatManager(CombatPlugin plugin) { this.plugin = plugin; }
    public void startCombat(Player player) {
        UUID uuid = player.getUniqueId();
        combatTimers.put(uuid, System.currentTimeMillis() + COMBAT_DURATION);
        BossBar bar = bossBars.computeIfAbsent(uuid, k -> Bukkit.createBossBar("Бой! Не покидайте сервер", BarColor.RED, BarStyle.SOLID));
        bar.addPlayer(player);
    }
    public boolean isInCombat(Player player) {
        Long expiry = combatTimers.get(player.getUniqueId());
        if (expiry == null) return false;
        if (System.currentTimeMillis() > expiry) { stopCombat(player); return false; }
        return true;
    }
    public void stopCombat(Player player) {
        UUID uuid = player.getUniqueId();
        combatTimers.remove(uuid);
        BossBar bar = bossBars.remove(uuid);
        if (bar != null) bar.removeAll();
    }
    public void updateTimers() {
        long now = System.currentTimeMillis();
        for (Player player : Bukkit.getOnlinePlayers()) {
            UUID uuid = player.getUniqueId();
            Long expiry = combatTimers.get(uuid);
            if (expiry != null) {
                if (now > expiry) stopCombat(player);
                else {
                    long secondsLeft = (expiry - now) / 1000 + 1;
                    BossBar bar = bossBars.get(uuid);
                    if (bar != null) {
                        bar.setTitle("Бой! Кулдаун команд: " + secondsLeft + " сек.");
                        bar.setProgress(Math.max(0.0, Math.min(1.0, (double) secondsLeft / 30.0)));
                    }
                }
            }
        }
    }
    public void handleQuit(Player player) {
        if (isInCombat(player)) { player.setHealth(0); stopCombat(player); }
    }
}
EOF

# Создание CombatListener.java
cat <<EOF > src/main/java/me/combat/CombatListener.java
package me.combat;
import org.bukkit.ChatColor;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.entity.EntityDamageByEntityEvent;
import org.bukkit.event.player.PlayerCommandPreprocessEvent;
import org.bukkit.event.player.PlayerQuitEvent;
import java.util.Arrays;
import java.util.List;
public class CombatListener implements Listener {
    private final CombatManager combatManager;
    private final List<String> blockedCommands = Arrays.asList("/home", "/spawn", "/tpa", "/rtp");
    public CombatListener(CombatManager combatManager) { this.combatManager = combatManager; }
    @EventHandler
    public void onPlayerDamage(EntityDamageByEntityEvent event) {
        if (event.getEntity() instanceof Player victim && event.getDamager() instanceof Player attacker) {
            combatManager.startCombat(victim);
            combatManager.startCombat(attacker);
        }
    }
    @EventHandler
    public void onCommand(PlayerCommandPreprocessEvent event) {
        Player player = event.getPlayer();
        String message = event.getMessage().toLowerCase();
        if (combatManager.isInCombat(player)) {
            for (String cmd : blockedCommands) {
                if (message.startsWith(cmd)) {
                    event.setCancelled(true);
                    player.sendMessage(ChatColor.RED + "Вы в бою! Команда " + cmd + " недоступна.");
                    return;
                }
            }
        }
    }
    @EventHandler
    public void onQuit(PlayerQuitEvent event) {
        combatManager.handleQuit(event.getPlayer());
    }
}
EOF

# Создание build.yml
cat <<EOF > .github/workflows/build.yml
name: Build Plugin
on:
  push:
    branches: [ "main", "master" ]
  pull_request:
    branches: [ "main", "master" ]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Set up JDK 17
      uses: actions/setup-java@v4
      with:
        java-version: '17'
        distribution: 'temurin'
        cache: maven
    - name: Build with Maven
      run: mvn clean package
    - name: Upload Artifact
      uses: actions/upload-artifact@v4
      with:
        name: CombatCooldown-Plugin
        path: target/*.jar
EOF

echo "Структура проекта успешно создана!"
