output "ssh" {
  value = <<EOS

bastion ip : ${aws_eip.bastion.public_ip}
ssh connection.
```
ssh ec2-user@${aws_eip.bastion.public_ip} -i ${var.ssh_key_file}
```

connect with ssh to local web/api server after connect to "bastion" ...
web : 
[ec2-user@bastion ~]$ ssh web
api :
[ec2-user@bastion ~]$ ssh api

recomend
```
$ vim ~/.ssh/config
Host ${var.profile_name} 
  HostName     ${aws_eip.bastion.public_ip}
  User         ec2-user
  IdentityFile ${var.ssh_key_file}

Host ${var.profile_name}+*
  IdentityFile ${var.ssh_key_file}
  User         ec2-user
  ProxyCommand ssh -W "$(sed -E 's/.*\+//'<<<"%h")":%p "$(sed -E 's/\+[^\+]*//'<<<"%h")"
```

you can ssh connect to bastion > web 
$ ssh ${var.profile_name}+web
EOS
}

output "mysql" {
  value = <<EOS

main mysql : ${aws_db_instance.main.address}

connect to mysql after connect to web/api ...
main mysql : 
[ec2-user@web ~]$ mysql -u ${var.mysql_user} -p -h ${aws_db_instance.main.address} ${var.mysql_db}
EOS
}
