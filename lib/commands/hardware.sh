# about: Hardware Information: CPU, memory, disks, PCI and USB devices
# category: Hardware
cmd_hardware_help() { echo "Usage: yayap hardware [all|cpu|memory|disks|pci|usb]"; }
cmd_hardware() {
    local what="${1:-all}"
    case "$what" in all|cpu|memory|disks|pci|usb) ;; *) cmd_hardware_help; return 1 ;; esac

    if [[ "$what" == all || "$what" == cpu ]]; then
        header "CPU"
        if has lscpu; then
            lscpu | grep -E '^(Model name|Architecture|CPU\(s\)|Thread|Core|Socket|CPU max MHz|Virtualization|L3)' | sed 's/^/  /'
        else
            grep -m1 'model name' /proc/cpuinfo | sed 's/^/  /'; kv "Threads" "$(nproc)"
        fi
    fi
    if [[ "$what" == all || "$what" == memory ]]; then
        header "Memory"
        if has free; then free -h | sed 's/^/  /'; else head -n 3 /proc/meminfo | sed 's/^/  /'; fi
    fi
    if [[ "$what" == all || "$what" == disks ]]; then
        header "Disks"
        if has lsblk; then lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT 2>/dev/null | sed 's/^/  /'
        else sed 's/^/  /' /proc/partitions
        fi
    fi
    if [[ "$what" == all || "$what" == pci ]]; then
        header "PCI devices"
        if has lspci; then lspci | sed 's/^/  /'; else echo "  (install pciutils for lspci)"; fi
    fi
    if [[ "$what" == all || "$what" == usb ]]; then
        header "USB devices"
        if has lsusb; then lsusb | sed 's/^/  /'; else echo "  (install usbutils for lsusb)"; fi
    fi
    return 0
}
cmd_hardware_actions() {
    cat <<'A'
Everything|all
Processor|cpu
Memory|memory
Disks and partitions|disks
PCI devices (GPU, network, …)|pci
USB devices|usb
A
}
