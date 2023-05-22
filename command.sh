### ---------
### VAR ###
### ---------

# ONTAP IMFO
SVM_NAME_SRC=svm1
SVM_NAME_DEST=svmbk1
AGGR_NAME=soc_ontap_01_SSD_1
TMP_VOL_NAME_DEST=dest_sm01
TMP_CLONE_NAME=fvolume01
VOL_SIZE=10Gi

# Kubernetes / TRIDENT INFO
NAMESPACE=default
POD_NAME=catalog-mysql-0
BACKEND_NAME=bk-ontapnas
TRIDENT_PREFIX="trident_svm1_34_"
STORAGE_CLASS=ontap-nas
TRIDENT_IMPORT_FILE=trident_import.yaml

# Other
PVC_NAME_SRC=`kubectl get pod $POD_NAME -o custom-columns='DATA:spec.volumes[*].persistentVolumeClaim.claimName'|grep -v DATA`
PV_NAME_SRC=`kubectl get pv|grep $PVC_NAME_SRC|cut -f 1 -d " "`
VOL_NAME_SRC=$TRIDENT_PREFIX`echo $PV_NAME_SRC|sed -e s/-/_/g`

### ---------
### COMMAND ###
### ---------

# Ontapコマンド生成: snapmirror
echo "- ontap snapmirror"
echo "volume create -vserver $SVM_NAME_DEST -aggregate $AGGR_NAME -type DP -size 10g -volume $TMP_VOL_NAME_DEST"
echo "snapmirror initialize -destination-path $SVM_NAME_DEST:$TMP_VOL_NAME_DEST -source-path $SVM_NAME_SRC:$VOL_NAME_SRC"
echo "snapmirror show -destination-path $SVM_NAME_DEST:$TMP_VOL_NAME_DEST -source-path $SVM_NAME_SRC:$VOL_NAME_SRC"
echo "snapmirror break -destination-path $SVM_NAME_DEST:$TMP_VOL_NAME_DEST -source-path $SVM_NAME_SRC:$VOL_NAME_SRC"

# Ontapコマンド生成: clone / rehost
echo "- ontap clone"
echo "volume clone create -parent-volume $VOL_NAME_SRC -vserver $SVM_NAME_SRC -flexclone $TMP_CLONE_NAME"
echo "volume clone split start -vserver $SVM_NAME_SRC -flexclone $TMP_CLONE_NAME"
echo "volume rehost -vserver $SVM_NAME_SRC -volume $TMP_CLONE_NAME -destination-vserver $SVM_NAME_DEST"



# Trident コマンド生成
echo "- trident import "
echo "tridentctl -n trident import volume $BACKEND_NAME $TMP_VOL_NAME_DEST -f $TRIDENT_IMPORT_FILE"

#  IMPORT FILE生成
cat << EOF > $TRIDENT_IMPORT_FILE
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $PVC_NAME
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: $STORAGE_CLASS
  resources:
    requests:
        storage: $VOL_SIZE
EOF
