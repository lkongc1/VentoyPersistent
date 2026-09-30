#!/bin/bash
set -e

echo "=== Configuración Automática de Persistencia Ventoy ==="

# 1. Detectar partición de Ventoy
VENTOY_DEV=$(blkid -L VENTOY 2>/dev/null || true)

if [ -z "$VENTOY_DEV" ]; then
    echo "[!] No se encontró automáticamente la etiqueta 'VENTOY'."
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
    echo ""
    read -p "Ingresa la partición de tu USB manualmente (ej: /dev/sdb1): " VENTOY_DEV
fi

echo "[+] Dispositivo detectado: $VENTOY_DEV"

# 2. Descargar generador de Ventoy
echo "[+] Descargando generador de persistencia oficial..."
curl -sO https://raw.githubusercontent.com/ventoy/backend/master/CreatePersistentImg.sh

# 3. Crear archivo .dat de 4GB
echo "[+] Generando archivo de persistencia (4GB ext4 vtoycow)..."
bash CreatePersistentImg.sh -s 4096 -t ext4 -l vtoycow -f arch_persist.dat

# 4. Montar USB
MOUNT_DIR="/mnt/ventoy_usb"
mkdir -p "$MOUNT_DIR"
mount "$VENTOY_DEV" "$MOUNT_DIR"

# 5. Mover la persistencia al USB
echo "[+] Moviendo arch_persist.dat al USB..."
mv arch_persist.dat "$MOUNT_DIR/"

# 6. Auto-detectar nombre de la ISO de Arch
ISO_NAME=$(ls "$MOUNT_DIR" | grep -i "archlinux.*\.iso" | head -n 1)

if [ -z "$ISO_NAME" ]; then
    echo "[!] No se autodetectó la ISO en la raíz del USB."
    read -p "Escribe el nombre exacto del archivo .iso: " ISO_NAME
fi

# 7. Generar ventoy.json
mkdir -p "$MOUNT_DIR/ventoy"

cat <<EOF > "$MOUNT_DIR/ventoy/ventoy.json"
{
    "persistence": [
        {
            "image_path": "/$ISO_NAME",
            "backend": [
                "/arch_persist.dat"
            ]
        }
    ]
}
EOF

# 8. Limpieza final
umount "$MOUNT_DIR"
rm -rf "$MOUNT_DIR" CreatePersistentImg.sh

echo "=================================================="
echo " ¡PROCESO COMPLETADO! Ya puedes reiniciar."
echo "=================================================="