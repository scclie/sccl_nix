{ config, lib, pkgs, ... }:
let
  cfg = config.sccl.databases;
in {
  options.sccl.databases = {
    enable = lib.mkEnableOption "PostgreSQL and Redis databases";
    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/tank/db";
      description = "ZFS dataset for database storage";
    };
  };

  config = lib.mkIf cfg.enable {
    # PostgreSQL
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_16;
      dataDir = "${cfg.dataDir}/postgresql";
      settings = {
        max_connections = 100;
        shared_buffers = "512MB";
        effective_cache_size = "1536MB";
        maintenance_work_mem = "128MB";
        checkpoint_completion_target = 0.9;
        wal_buffers = "16MB";
        default_statistics_target = 100;
        random_page_cost = 1.1;
        effective_io_concurrency = 200;
        work_mem = "4MB";
        huge_pages = "try";
        min_wal_size = "1GB";
        max_wal_size = "4GB";
        max_worker_processes = 4;
        max_parallel_workers_per_gather = 2;
        max_parallel_workers = 4;
        max_parallel_maintenance_workers = 2;
      };
    };

    # Redis
    services.redis.servers.default = {
      enable = true;
      bind = "127.0.0.1";
      port = 6379;
      settings = {
        maxmemory = "256mb";
        maxmemory-policy = "allkeys-lru";
        save = [ "900 1" "300 10" "60 10000" ];
      };
    };

    # Ensure data directory exists (0700 — PostgreSQL refuses to start otherwise)
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 postgres postgres -"
      "d ${cfg.dataDir}/postgresql 0700 postgres postgres -"
    ];
  };
}
