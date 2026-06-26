package me.combat;

import org.bukkit.ChatColor;
import org.bukkit.entity.Player;
import org.bukkit.entity.Projectile;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.entity.EntityDamageByEntityEvent;
import org.bukkit.event.player.PlayerCommandPreprocessEvent;
import org.bukkit.event.player.PlayerQuitEvent;

import java.util.Arrays;
import java.util.List;

public class CombatListener implements Listener {
    private final CombatManager combatManager;
    private final List<String> blockedCommands = Arrays.asList("/home", "/spawn", "/tpa", "/rtp");

    public CombatListener(CombatManager combatManager) {
        this.combatManager = combatManager;
    }

    @EventHandler(priority = EventPriority.MONITOR)
    public void onPlayerDamage(EntityDamageByEntityEvent event) {
        if (!(event.getEntity() instanceof Player victim)) return;

        Player attacker = null;

        // 1. Проверка: прямой удар игроком
        if (event.getDamager() instanceof Player p) {
            attacker = p;
        } 
        // 2. Проверка: урон от снаряда (пули TacZ, стрелы и т.д.)
        else if (event.getDamager() instanceof Projectile projectile) {
            if (projectile.getShooter() instanceof Player p) {
                attacker = p;
            }
        }

        if (attacker != null) {
            // Чтобы не спамить в консоль каждую секунду, можно убрать этот лог позже
            CombatPlugin.getInstance().getLogger().info("Бой зафиксирован: " + attacker.getName() + " -> " + victim.getName());
            
            combatManager.startCombat(victim);
            combatManager.startCombat(attacker);
        }
    }

    @EventHandler(priority = EventPriority.HIGHEST)
    public void onCommand(PlayerCommandPreprocessEvent event) {
        Player player = event.getPlayer();
        String message = event.getMessage().toLowerCase();

        if (combatManager.isInCombat(player)) {
            for (String cmd : blockedCommands) {
                if (message.startsWith(cmd)) {
                    CombatPlugin.getInstance().getLogger().info("Блокировка команды " + cmd + " для игрока " + player.getName());
                    event.setCancelled(true);
                    player.sendMessage(ChatColor.RED + "Вы в бою! Команда " + cmd + " недоступна.");
                    return;
                }
            }
        }
    }

    @EventHandler
    public void onQuit(PlayerQuitEvent event) {
        Player player = event.getPlayer();
        combatManager.handleQuit(player);
    }
}
