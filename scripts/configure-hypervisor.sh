#!/bin/bash

# Copyright (c) 2017-2018 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#---------------------------------------------------------------------
# Description: This script is the *ONLY* place where "qemu*" build options
# should be defined.
#
# Note to maintainers:
#
# XXX: Every option group *MUST* be documented explaining why it has
# been specified.
#---------------------------------------------------------------------

script_name=${0##*/}

typeset -A recognised_tags

recognised_tags=(
    [arch]="architecture-specific"
    [minimal]="specified to avoid building unnecessary elements"
    [misc]="miscellaneous"
    [security]="specified for security reasons"
    [size]="minimise binary size"
    [speed]="maximise startup speed"
)

# Display message to stderr and exit indicating script failed.
die()
{
    local msg="$*"
    echo >&2 "$script_name: ERROR: $msg"
    exit 1
}

# Display usage to stdout.
usage()
{
cat <<EOT
Overview:

    Display configure options required to build the specified
    hypervisor.

Usage:

    $script_name [options] <hypervisor-name>

Options:

    -d : Dump all options along with the tags explaining why each option
         is specified.
    -h : Display this help.
    -m : Display options one per line (includes continuation characters).

Example:

    $ $script_name qemu-lite

EOT
}

show_tags_header()
{
	local keys
	local key
	local value

	cat <<EOT
# Recognised option tags:
#
EOT

        # sort the tags
	keys=${!recognised_tags[@]}
	keys=$(echo "$keys"|tr ' ' '\n'|sort -u)

	for key in $keys
	do
		value="${recognised_tags[$key]}"
		printf "#    %s\t%s.\n" "$key" "$value"
	done

	printf "#\n\n"
}

check_tag()
{
	local tag="$1"
	local entry="$2"

	value="${recognised_tags[$tag]}"

	[ -n "$value" ] && return

	die "invalid tag '$tag' found for entry '$entry'"
}

check_tags()
{
	local tags="$1"
	local entry="$2"

        [ -z "$tags" ] && die "entry '$entry' doesn't have any tags"

	tags=$(echo "$tags"|tr ',' '\n')

	for tag in $tags
	do
		check_tag "$tag" "$entry"
	done
}

# Display an array to stdout.
#
# If 2 arguments are specified, split array across multiple lines,
# one per element with a backslash at the end of all lines except
# the last.
#
# Arguments:
#
# $1: *Name* of array variable (no leading '$'!!)
# $2: (optional) "multi" - show values across multiple lines,
#    "dump" - show full hash values. Any other value results in the
#    options being displayed on a single line.
show_array()
{
    local -n _array="$1"
    local action="$2"

    local -i size="${#_array[*]}"
    local -i i=1
    local entry
    local tags
    local elem
    local suffix
    local one_line="no"

    [ "$action" = "dump" ] && show_tags_header

    for entry in "${_array[@]}"
    do
        tags=$(echo "$entry"|cut -s -d: -f1)
        elem=$(echo "$entry"|cut -s -d: -f2-)

	check_tags "$tags" "$entry"

        if [ "$action" = "dump" ]
        then
            printf "%s\t\t%s\n" "$tags" "$elem"
        elif [ "$action" = "multi" ]
        then
            if [ $i -eq $size ]
            then
                suffix=""
            else
                suffix=" \\"
            fi

            printf '%s%s\n' "$elem" "$suffix"
        else
            one_line="yes"
            echo -n "$elem "
        fi

        i+=1
    done

    [ "$one_line" = yes ] && echo
}

# Entry point
main()
{
    arch=$(arch)

    # Array of configure options.
    #
    # Each element is comprised of two parts in the form:
    #
    #     tags:option
    #
    # Where,
    #
    # - 'tags' is a comma-separated list of values which denote why
    #   the option is being specified.
    #
    # - 'option' is the hypervisor configuration option.
    typeset -a qemu_options

    action=""

    while getopts "dhm" opt
    do
        case "$opt" in
            d)
                action="dump"
                ;;

            h)
                usage
                exit 0
                ;;

            m)
                action="multi"
                ;;
        esac
    done

    shift $[$OPTIND-1]

    [ -z "$1" ] && die "need hypervisor name"
    hypervisor="$1"

    #---------------------------------------------------------------------
    # Disabled options

    # bluetooth support not required
    qemu_options+=(size:--disable-bluez)

    # braille support not required
    qemu_options+=(size:--disable-brlapi)

    # Don't build documentation
    qemu_options+=(minimal:--disable-docs)

    # Disable GUI (graphics)
    qemu_options+=(size:--disable-curses)
    qemu_options+=(size:--disable-gtk)
    qemu_options+=(size:--disable-opengl)
    qemu_options+=(size:--disable-sdl)
    qemu_options+=(size:--disable-spice)
    qemu_options+=(size:--disable-vte)

    # Disable graphical network access
    qemu_options+=(size:--disable-vnc)
    qemu_options+=(size:--disable-vnc-jpeg)
    qemu_options+=(size:--disable-vnc-png)
    qemu_options+=(size:--disable-vnc-sasl)

    # Disable unused filesystem support
    qemu_options+=(size:--disable-fdt)
    qemu_options+=(size:--disable-glusterfs)
    qemu_options+=(size:--disable-libiscsi)
    qemu_options+=(size:--disable-libnfs)
    qemu_options+=(size:--disable-libssh2)
    qemu_options+=(size:--disable-rbd)

    # Disable unused compression support
    qemu_options+=(size:--disable-bzip2)
    qemu_options+=(size:--disable-lzo)
    qemu_options+=(size:--disable-snappy)

    # Disable unused security options
    qemu_options+=(security:--disable-seccomp)
    qemu_options+=(security:--disable-tpm)

    # Disable userspace network access ("-net user")
    qemu_options+=(size:--disable-slirp)

    # Disable USB
    qemu_options+=(size:--disable-libusb)
    qemu_options+=(size:--disable-usb-redir)

    # Don't build a static binary (lowers security)
    qemu_options+=(security:--disable-static)

    # Not required as "-uuid ..." is always passed to the qemu binary
    qemu_options+=(size:--disable-uuid)

    # Disable debug
    qemu_options+=(size:--disable-debug-tcg)
    qemu_options+=(size:--disable-qom-cast-debug)
    qemu_options+=(size:--disable-tcg-interpreter)
    qemu_options+=(size:--disable-tcmalloc)

    # Disallow network downloads
    qemu_options+=(security:--disable-curl)

    # Disable Remote Direct Memory Access (Live Migration)
    # https://wiki.qemu.org/index.php/Features/RDMALiveMigration
    qemu_options+=(size:--disable-rdma)

    # Don't build the qemu-io, qemu-nbd and qemu-image tools
    qemu_options+=(size:--disable-tools)

    # Disable XEN driver
    qemu_options+=(size:--disable-xen)

    # FIXME: why is this disabled?
    # (for reference, it's explicitly enabled in Ubuntu 17.10 and
    # implicitly enabled in Fedora 27).
    qemu_options+=(size:--disable-linux-aio)

    # In "passthrough" security mode
    # (-fsdev "...,security_model=passthrough,..."), qemu uses a helper
    # application called virtfs-proxy-helper(1) to make certain 9p
    # operations safer. We don't need that, so disable it (and it's
    # dependencies).
    qemu_options+=(size:--disable-virtfs)
    qemu_options+=(size:--disable-attr)
    qemu_options+=(size:--disable-cap-ng)

    #---------------------------------------------------------------------
    # Enabled options

    # Enable kernel Virtual Machine support.
    # This is the default, but be explicit to avoid any future surprises
    qemu_options+=(speed:--enable-kvm)

    # Required for fast network access
    qemu_options+=(speed:--enable-vhost-net)

    # Always strip binaries
    qemu_options+=(size:--enable-strip)

    #---------------------------------------------------------------------
    # Other options

    # 64-bit only
    [ "$arch" = x86_64 ] && qemu_options+=(arch:"--target-list=${arch}-softmmu")

    _qemu_cflags=""

    # compile with high level of optimisation
    _qemu_cflags+=" -O3"

    # Improve code quality by assuming identical semantics for interposed
    # synmbols.
    _qemu_cflags+=" -fno-semantic-interposition"

    # Performance optimisation
    _qemu_cflags+=" -falign-functions=32"

    # SECURITY: make the compiler check for common security issues
    # (such as argument and buffer overflows checks).
    _qemu_cflags+=" -D_FORTIFY_SOURCE=2"

    # SECURITY: Create binary as a Position Independant Executable,
    # and take advantage of ASLR, making ROP attacks much harder to perform.
    # (https://wiki.debian.org/Hardening)
    _qemu_cflags+=" -fPIE"

    # Set compile options
    qemu_options+=(security,speed,size:"--extra-cflags=\"${_qemu_cflags}\"")

    unset _qemu_cflags

    _qemu_ldflags=""

    # SECURITY: Link binary as a Position Independant Executable,
    # and take advantage of ASLR, making ROP attacks much harder to perform.
    # (https://wiki.debian.org/Hardening)
    _qemu_ldflags+=" -pie"

    # SECURITY: Disallow executing code on the stack.
    _qemu_ldflags+=" -z noexecstack"

    # SECURITY: Make the linker set some program sections to read-only
    # before the program is run to stop certain attacks.
    _qemu_ldflags+=" -z relro"

    # SECURITY: Make the linker resolve all symbols immediately on program
    # load.
    _qemu_ldflags+=" -z now"

    qemu_options+=(security:"--extra-ldflags=\"${_qemu_ldflags}\"")

    unset _qemu_ldflags

    # Where to install qemu libraries
    [ "$arch" = x86_64 ] && qemu_options+=(arch:--libdir=/usr/lib64/${hypervisor})

    # Where to install qemu helper binaries
    qemu_options+=(misc:--libexecdir=/usr/libexec/${hypervisor})

    # Where to install data files
    qemu_options+=(misc:--datadir=/usr/share/${hypervisor})

    show_array qemu_options "$action"

    exit 0
}

main $@
