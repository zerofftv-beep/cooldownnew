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
    private final long COMBAT_DURATION = 30 * 1000L; // 30 seconds

    public CombatManager(CombatPlugin plugin) {
        this.plugin = plugin;
    }

    public void startCombat(Player player) {
        UUID uuid = player.getUniqueId();
        combatTimers.put(uuid, System.currentTimeMillis() + COMBAT_DURATION);
        
        // Create BossBar if it doesn't exist
        BossBar bar = bossBars.computeIfAbsent(uuid, k -> {
            BossBar b = Bukkit.createBossBar("Бой! Не покидайте сервер", BarColor.RED, BarStyle.SOLID);
            return b;
        });
        bar.addPlayer(player);
    }

    public boolean isInCombat(Player player) {
        Long expiry = combatTimers.get(player.getUniqueId());
        if (expiry == null) return false;
        if (System.currentTimeMillis() > expiry) {
            stopCombat(player);
            return false;
        }
        return true;
    }

    public void stopCombat(Player player) {
        UUID uuid = player.getUniqueId();
        combatTimers.remove(uuid);
        BossBar bar = bossBars.remove(uuid);
        if (bar != null) {
            bar.removeAll();
        }
    }

    public void updateTimers() {
        long now = System.currentTimeMillis();
        for (Player player : Bukkit.getOnlinePlayers()) {
            UUID uuid = player.getUniqueId();
            Long expiry = combatTimers.get(uuid);
            
            if (expiry != null) {
                if (now > expiry) {
                    stopCombat(player);
                } else {
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
        if (isInCombat(player)) {
            String playerName = player.getName();
            
            // 1. Сначала обнуляем здоровье (это переводит в нокдаун)
            player.setHealth(0);
            
            // 2. Выполняем команду /kill дважды от имени консоли, чтобы добить игрока окончательно
            // Первый раз может зафиксировать смерть/нокдаун, второй — окончательно убить
            Bukkit.dispatchCommand(Bukkit.getConsoleSender(), "kill " + playerName);
            Bukkit.dispatchCommand(Bukkit.getConsoleSender(), "kill " + playerName);
            
            CombatPlugin.getInstance().getLogger().info("Игрок " + playerName + " покинул сервер в бою и был принудительно убит (Double Kill).");
            stopCombat(player);
        }
    }
}
