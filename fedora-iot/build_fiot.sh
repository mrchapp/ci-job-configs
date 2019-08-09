#!/bin/sh -x

set -e

wget -c ${URL}/${IMG}

xz -d ${IMG}
IMG=${IMG%.xz}

sudo -E ./guestfish_${MACHINE}.sh ${IMG}

echo "build complete"
