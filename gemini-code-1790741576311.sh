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

# 2. Comprobar si ya está montado en el sistema Live
CURRENT_MOUNT=$(findmnt -n -o TARGET "$VENTOY_DEV" | head -n 1 || true)

if [ -n "$CURRENT_MOUNT" ]; then
    echo "[+] La partición ya está montada en: $CURRENT_MOUNT"
    MOUNT_DIR="$CURRENT_MOUNT"
    # Asegurar permisos de escritura
    mount -o remount,rw "$MOUNT_DIR" 2>/dev/null || true
    WAS_ALREADY_MOUNTED=1
else
    MOUNT_DIR="/mnt/ventoy_usb"
    mkdir -p "$MOUNT_DIR"
    mount "$VENTOY_DEV" "$MOUNT_DIR"
    WAS_ALREADY_MOUNTED=0
fi

# 3. Crear archivo .dat de 4GB DIRECTAMENTE en la ruta montada
echo "[+] Generando archivo de persistencia de 4GB en el USB..."
echo "[!] Esto puede tardar unos minutos dependiendo de la velocidad del USB."
dd if=/dev/zero of="$MOUNT_DIR/arch_persist.dat" bs=1M count=4096 status=progress

# 4. Formatear contenedor con ext4 y etiqueta vtoycow
echo "[+] Formateando contenedor de persistencia..."
mkfs.ext4 -F -L vtoycow "$MOUNT_DIR/arch_persist.dat"

# 5. Detectar la ISO en la raíz de la partición
ISO_NAME=$(ls "$MOUNT_DIR" | grep -i "archlinux.*\.iso" | head -n 1 || true)

if [ -z "$ISO_NAME" ]; then
    echo "[!] No se encontró la ISO automáticamente en $MOUNT_DIR."
    read -p "Escribe el nombre exacto del archivo .iso: " ISO_NAME
fi

# 6. Generar la configuración ventoy.json
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

# 7. Forzar la sincronización de datos al USB
echo "[+] Guardando cambios en la memoria USB (sync)..."
sync

if [ "$WAS_ALREADY_MOUNTED" -eq 0 ]; then
    umount "$MOUNT_DIR"
    rm -rf "$MOUNT_DIR"
fi

echo "=================================================="
echo " ¡PROCESO COMPLETADO! Ya puedes reiniciar."
echo "=================================================="
