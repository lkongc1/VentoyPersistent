#!/bin/bash
set -e

echo "=== Configuración Automática de Persistencia Ventoy ==="

# 1. Detectar partición de Ventoy
VENTOY_DEV=$(blkid -L VENTOY 2>/dev/null || true)

if [ -z "$VENTOY_DEV" ]; then
    echo "[!] No se encontró automáticamente la etiqueta 'VENTOY'."
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
    echo ""
    read -p "Ingresa la partición de tu USB manualmente (ej: /dev/sda1): " VENTOY_DEV
fi

echo "[+] Dispositivo detectado: $VENTOY_DEV"

# 2. Montar el USB PRIMERO para no llenar la memoria RAM
MOUNT_DIR="/mnt/ventoy_usb"
mkdir -p "$MOUNT_DIR"
mount "$VENTOY_DEV" "$MOUNT_DIR"

# 3. Crear archivo .dat de 4GB DIRECTAMENTE en el USB
echo "[+] Generando archivo de persistencia de 4GB en la memoria USB..."
echo "[!] Esto puede tardar un par de minutos según la velocidad de tu USB."
dd if=/dev/zero of="$MOUNT_DIR/arch_persist.dat" bs=1M count=4096 status=progress

# 4. Darle formato ext4 con la etiqueta requerida vtoycow
echo "[+] Formateando el contenedor de persistencia..."
mkfs.ext4 -F -L vtoycow "$MOUNT_DIR/arch_persist.dat"

# 5. Auto-detectar nombre de la ISO de Arch en el USB
ISO_NAME=$(ls "$MOUNT_DIR" | grep -i "archlinux.*\.iso" | head -n 1)

if [ -z "$ISO_NAME" ]; then
    echo "[!] No se autodetectó la ISO en la raíz del USB."
    read -p "Escribe el nombre exacto del archivo .iso: " ISO_NAME
fi

# 6. Generar el archivo de configuración ventoy.json
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

# 7. Desmontar USB de forma segura
echo "[+] Guardando cambios y desmontando USB..."
sync
umount "$MOUNT_DIR"
rm -rf "$MOUNT_DIR"

echo "=================================================="
echo " ¡PROCESO COMPLETADO! Ya puedes reiniciar."
echo "=================================================="
