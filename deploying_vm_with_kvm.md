Deploying VM with `virsh` on a headless Linux server
====================================================


Presentation of the utils
-------------------------


### KVM

KVM stands for Kernel-based Virtual Machine. By itself, KVM does not
perform any emulation. Instead, it exposes an interface, which a
userspace host can then use to feed the guest simulated IO, map the
guest's video display back onto the system host, etc.

KVM allows to use the virtualisation extensions of modern processors.
So that a slice of the physical CPU can be directly mapped to the
virtual CPU. Therefor the instructions meant for the virtual CPU can be
directly executed on the physical CPU slice.


### QEMU

QEMU is a hosted virtual machine monitor: it emulates CPUs through
dynamic binary translation and provides a set of device models, enabling
it to run a variety of unmodified guest operating systems. It also can
be used with KVM to run virtual machines at near-native speed (requiring
hardware virtualization extensions on x86 machines). QEMU can also do
CPU emulation for user-level processes, allowing applications compiled
for one architecture to run on another.

QEMU has multiple operating modes:

- *User-mode emulation:* run single programs that where compiled for a
  different instruction set.
- *System emulation:* emulate a full computer system, including
  peripherals.
- *KVM Hosting:* same has System Emulation but the execution of the
  guest is done by KVM.
- *Xen Hosting:* same has System Emulation but the execution of the
  guest is done by Xen.

On Linux, QEMU is one such userspace host. QEMU uses KVM when available
to virtualise guests at near-native speeds, but otherwise falls back to
software-only emulation.


Connect to the server
---------------------

It's important to connect to your server with graphic option enabled:

    $ ssh -X user@myserver.srv


Installation
------------

Install packages:

    # apt install \
        qemu-kvm libvirt-daemon-system virtinst libguestfs-tools \
        xtightvncviewer net-tools

- *qemu-kvm:* QEMU, a fast processor emulator.
- *libvirt-deamon-system:* Libvirt is a C toolkit to interact with the
  virtualization capabilities of recent versions of Linux.
- *virtinst:* Virtinst is a set of commandline tools to create virtual
  machines using libvirt (e.g. *virt-install*, *virt-clone*, etc.)
- *libguestfs-tools:* The libguestfs library allows accessing and
  modifying guest disk images.
- *xtightvncviewer*: simple VNC viewer.
- *net-tools* provide important tools for controlling the network
  subsystem of the Linux kernel (arp, netstat, noute, etc.).

To be able to manage virtual machines as regular user, that
user needs to be added to some groups:

    # adduser <youruser> libvirt
    # adduser <youruser> libvirt-qemu

Reload group membership with the following commands:

    $ newgrp libvirt
    $ newgrp libvirt-qemu

Verify that you are in the right groups:

    $ id


Configure network
-----------------

We need to create a bridge interface. VM can connect to this bridge an
access to the main interface.

    # nano /etc/network/interfaces

```
#allow-hotplug enp0s3
#iface enp0s3 inet dhcp
auto br0
iface br0 inet dhcp
     bridge_ports enp0s3
```

You should remove all configuration of your main interface (here
`enp0s3`) and create the bridge. Here the bridge is configured over
DHCP.

Reboot the computer to take network into account. Pay attention that you
will lose your SSH connection. Or restart the network daemon:

    # systemctl restart networking


Create a KVM guest domain
-------------------------

The KVM guest domain should be configured on the bridge network created
before. In order to do that create `/root/bridged.xml` with the
following:

    # nano /root/bridged.xml

```xml
<network>
  <name>br0</name>
  <forward mode="bridge"/>
  <bridge name="br0"/>
</network>
```

Then the bridge should be activated for VM.

    # virsh net-define --file /root/bridged.xml
    # virsh net-autostart br0
    # virsh net-start br0

Verify with:

    # virsh net-list --all


List supported guest OS
-----------------------

To list all supported OS, first install:

    # apt install libosinfo-bin

Then to get the list of supported Debian OS do:

    $ osinfo-query os | grep debian


Install a new VM
----------------

Download the iso image of your guest OS:

    # wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-9.4.0-amd64-netinst.iso

Create the virtual machine and launch the installer in text mode:

    virt-install -v \
      --virt-type kvm \ # if installed in a VM need to use qemu
      --hvm \ # remove if using qemu
      --name debian-amd64 \
      --os-variant debian9 \ # need to delete becauase not found
      --cdrom ~/debian-9.4.0-amd64-netinst.iso \
      --vcpus 1 \
      --memory 512 \
      --disk size=4 \
      --network bridge=br0,model=virtio \
      --graphics vnc

* `--virt-type` is the hypervisor to install on (kvm, qemu or xen).
* `--hvm` request the use of full virtualisation.
* `--disk size=4` means a disk of 4 Go.
* `--memory 512` means RAM of 512 Mo.
* `--graphics vnc` means installation with VNC.
* `--os-variant debian9` is not required but highly recommended
  has it increase performance.
* `--location` allows to pull the iso on the web instead of downloading it.

        --location http://httpredir.debian.org/debian/dists/squeeze/main/installer-amd64/ \
        --extra-args "console=ttyS0"

This should open a window where you can do the installation.

After the installation you can connect by VNC with an ssh tunnel.

    # virsh list
    # virsh dumpxml debian-amd64 | grep vnc
        <graphics type='vnc' port='5900' autoport='yes' listen='127.0.0.1'>
    $ ssh user@server.srv -L 5900:localhost:5900

Then connect with a VNC client on localhost:5900.


Find IP address of a VM
-----------------------

First get his mac address:

    # virsh List
    # virsh dumpxml debian-amd64 | grep "mac address"

The search for addresses in the right IP range:

    # nmap -sn 10.0.2.0/24


Create a virtual machine using `virt-builder`
---------------------------------------------

List all the OS installable:

    $ virt-builder --list

Get more info about an OS:

    $ virt-builder --notes debian-9

Create the VM:

    # virt-builder debian-9 \
        --size 6G \
        --format qcow2 -o /var/lib/libvirt/images/debian9-vm.qcow2 \
        --hostname debian9-vm \
        --network \
        --timezone "Europe/Brussels"

Note the root password !

Finally import the image with virt-install command:

    # virt-install --import --name debian9 \
        --os-variant debian9 \
        --vcpus 1 \
        --memory 512 \
        --disk path=/var/lib/libvirt/images/debian9-vm.qcow2 \
        --network bridge=br0,model=virtio \
        --graphics vnc \
        --noautoconsole # do not open a console after import


Connect to a VM from the host
-----------------------------

Using the console:

    # virsh list
    # virsh console --safe <my_vm_name>

Using VNC:

    # virsh vncdisplay <my_vm_name>
    localhost:0
    # vncviewer localhost:0


Notes
-----

> *virt-viewer*: The console is accessed using the VNC protocol. 
> The guest can be referred to based on its name, ID, or UUID. 
> If the guest is not already running, then the viewer can be told to
> wait until is starts before attempting to connect to the console The
> viewer can connect to remote hosts to lookup the console information
> and then also connect to the remote console using the same network
> transport.  

> *virt-manager*: It presents a summary view of running domains and
> their live performance & resource utilization statistics. A detailed
> view presents graphs showing performance & utilization over time.
> Ultimately it will allow creation of new domains, and configuration &
> adjustment of a domain's resource allocation & virtual hardware.
> Finally an embedded VNC client viewer presents a full graphical
> console to the guest domain.
> <https://virt-manager.org/>

Sources
-------

* <https://wiki.debian.org/KVM>
* <https://www.mankier.com/1/virt-install>
* <https://www.cyberciti.biz/faq/install-kvm-server-debian-linux-9-headless-server/>
* <https://www.cyberciti.biz/faq/how-to-configuring-bridging-in-debian-linux/>

* <https://www.fir3net.com/UNIX/Linux/what-is-the-difference-between-qemu-and-kvm.html>
* <https://en.wikipedia.org/wiki/QEMU>
* <https://en.wikipedia.org/wiki/Kernel-based_Virtual_Machine>
* <https://fr.wikipedia.org/wiki/Hyperviseur>
