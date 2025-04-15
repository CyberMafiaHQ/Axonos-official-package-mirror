#!/bin/bash
set -e

# تنظیمات
DIST="bookworm"
ARCHS=("armhf" "arm64")
KEY_NAME="Axonos APT Repo"
KEY_EMAIL="apt@axon.os"
KEY_COMMENT="APT Signing Key"
KEY_FILE_NAME="axonos-public.asc"

# بررسی وجود کلید
KEY_ID=$(gpg --list-keys --with-colons | grep pub | cut -d: -f5 | tail -n1)

if [ -z "$KEY_ID" ]; then
    echo "🔐 کلید GPG پیدا نشد، در حال ساخت..."
    cat > key_batch <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Name-Real: $KEY_NAME
Name-Comment: $KEY_COMMENT
Name-Email: $KEY_EMAIL
Expire-Date: 0
%commit
EOF
    gpg --batch --gen-key key_batch
    rm key_batch
    KEY_ID=$(gpg --list-keys --with-colons | grep pub | cut -d: -f5 | tail -n1)
    echo "✅ کلید ساخته شد: $KEY_ID"
else
    echo "✅ کلید موجود است: $KEY_ID"
fi

# ساخت Packages.gz
echo "📦 ساخت Packages.gz برای معماری‌ها..."
for arch in "${ARCHS[@]}"; do
    mkdir -p dists/$DIST/main/binary-$arch
    dpkg-scanpackages -m pool /dev/null | gzip -9 > dists/$DIST/main/binary-$arch/Packages.gz
done

# ساخت فایل Release همراه Suite و Codename
echo "📝 ساخت Release..."
apt-ftparchive release dists/$DIST > dists/$DIST/Release.tmp

echo "Suite: $DIST" > dists/$DIST/Release
echo "Codename: $DIST" >> dists/$DIST/Release
cat dists/$DIST/Release.tmp >> dists/$DIST/Release
rm dists/$DIST/Release.tmp

# امضا کردن فایل Release
echo "🔏 امضای Release..."
gpg --default-key "$KEY_ID" --armor --detach-sign \
    --output dists/$DIST/Release.gpg dists/$DIST/Release

gpg --default-key "$KEY_ID" --clearsign \
    --output dists/$DIST/Release.txt dists/$DIST/Release

# استخراج کلید عمومی
echo "🔐 استخراج کلید عمومی به $KEY_FILE_NAME..."
gpg --armor --export "$KEY_ID" > $KEY_FILE_NAME

echo -e "\n✅ همه چیز آماده شد! فایل‌ها:"
echo " - dists/$DIST/Release"
echo " - dists/$DIST/Release.gpg"
echo " - dists/$DIST/Release.txt"
echo " - dists/$DIST/main/binary-*/Packages.gz"
echo " - $KEY_FILE_NAME"
echo -e "\n📤 آماده‌ی git push برای انتشار روی Netlify/GitHub Pages"
