{ pkgs, mailPasswordPath ? "/run/secrets/mail/app-password", ... }:

{
  programs.himalaya = {
    enable = true;
    package = pkgs.himalaya;
  };

  xdg.configFile."himalaya/config.toml".force = true;

  accounts.email.accounts.sccl = {
    enable = true;
    himalaya.enable = true;
    address = "sccl@sccl.cc";
    realName = "scclie";
    primary = true;
    userName = "sccl";

    imap = {
      host = "mail.sccl.cc";
      port = 993;
      tls.enable = true;
    };

    smtp = {
      host = "mail.sccl.cc";
      port = 465;
      tls.enable = true;
    };

    passwordCommand = "cat ${mailPasswordPath}";

    folders = {
      inbox = "INBOX";
      sent = "Sent Items";
      drafts = "Drafts";
      trash = "Deleted Items";
    };
  };
}
