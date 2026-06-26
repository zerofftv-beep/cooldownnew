package me.combat;

import org.bukkit.plugin.java.JavaPlugin;
import org.bukkit.scheduler.BukkitRunnable;

public class CombatPlugin extends JavaPlugin {
    private static CombatPlugin instance;
    private CombatManager combatManager;

    @Override
    public void onEnable() {
        instance = this;
        this.combatManager = new CombatManager(this);
        
        getServer().getPluginManager().registerEvents(new CombatListener(combatManager), this);
        
        new BukkitRunnable() {
            @Override
            public void run() {
                combatManager.updateTimers();
            }
        }.runTaskTimer(this, 0L, 20L);
        
        getLogger().info("CombatCooldown v1.1 loaded! Support for projectiles added.");
    }

    public static CombatPlugin getInstance() {
        return instance;
    }

    @Override
    public void onDisable() {
        getLogger().info("CombatCooldown disabled!");
    }
}
