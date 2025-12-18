# Ansible Instructions

This is an [Ansible](https://www.ansible.com/) playbook to automatically optimize and secure your servers for [Kamal](https://kamal-deploy.org/), for Ubuntu only.

## What's this do?

It will automatically update your packages and configure these packages to secure your server(s):

- [Docker](https://docs.docker.com/engine/install/ubuntu/)
- [Fail2ban](https://github.com/fail2ban/fail2ban)
- [UFW](https://wiki.ubuntu.com/UncomplicatedFirewall)
- [NTP](https://ubuntu.com/server/docs/network-ntp)

This playbook will also:

- Remove [Snap](https://snapcraft.io/).
- Disable ssh password login.
- Configure `swap` using [geerlingguy/ansible-role-swap](https://github.com/geerlingguy/ansible-role-swap).

## Getting Started

Get the `hosts.ini` file that has been gitignored and place it in this `ansible` directory.

Make sure Ansible is installed on your machine.  Installation instructions can be found [here](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html).

Install the requirements:
```bash
$ ansible-galaxy install -r requirements.yml
```

## Running the playbook

Run the playbook:
```bash
$ ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i hosts.ini playbook.yml --limit [environment-name]
```

`[environment-name]` can be `staging`, `production` or `webservers`. Using `webservers` will run the playbook on both environments.
