#!/usr/bin/env python3

import sys
import urllib.parse
import urllib.request
import re

from bs4 import BeautifulSoup, SoupStrainer

def validate_url(url):
    urllib.request.urlopen(url)

def get_image_url(page, base_url, rex_str):
    rex = re.compile(rex_str)
    url = ''
    soup = BeautifulSoup(page, "html.parser", parse_only=SoupStrainer("a"))
    for line in soup.find_all('a', href=True):
        s = rex.search(line['href'])
        if s:
            url = base_url + line['href']
            break
    return url

def get_base_url(url, job_url):
    f = urllib.request.urlopen(job_url + "lastSuccessfulBuild/buildNumber")
    last_build = int(f.read().decode("utf-8"))
    url = '%s/%d/' % (url, last_build)
    f = urllib.request.urlopen(url)
    page = f.read().decode("utf-8")
    base_url_p = urllib.parse.urlparse(url)
    base_url = "%s://%s" % (base_url_p.scheme, base_url_p.netloc)
    return (page, base_url)

def main(url='https://snapshots.linaro.org/member-builds/qcomlt/testimages/arm64/',
         job_url='https://ci.linaro.org/job/lt-qcom-linux-testimages/',
         desktop_url='https://snapshots.linaro.org/member-builds/qcomlt/testimages-desktop/arm64/',
         desktop_job_url='https://ci.linaro.org/job/lt-qcom-linux-testimages-desktop/',
         output='output.log'):

    (page, base_url) = get_base_url(url, job_url)
    ramdisk_url = get_image_url(page, base_url, 'initramfs-test-image-.*\.rootfs\.cpio\.gz$')
    validate_url(ramdisk_url)
    rootfs_url = get_image_url(page, base_url, 'rpb-console-image-test-.*\.rootfs\.img\.gz$')
    validate_url(rootfs_url)
    print('RAMDISK_URL=%s' % ramdisk_url)
    print('ROOTFS_URL=%s' % rootfs_url)

    (page, desktop_base_url) = get_base_url(desktop_url, desktop_job_url)
    rootfs_desktop_url = get_image_url(page, desktop_base_url, 'rpb-desktop-image-test-.*\.rootfs\.img\.gz$')
    validate_url(rootfs_desktop_url)
    print('ROOTFS_DESKTOP_URL=%s' % rootfs_desktop_url)

    print('Writting output to %s' % output)
    with open(output, 'w') as f:
        f.write("RAMDISK_URL=" + ramdisk_url + '\n')
        f.write("ROOTFS_URL=" + rootfs_url + '\n')
        f.write("ROOTFS_DESKTOP_URL=" + rootfs_desktop_url + '\n')

if __name__ == "__main__":
    main(*sys.argv[1:])
