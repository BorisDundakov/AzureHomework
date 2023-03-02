kubectl create secret generic db-csv \
    --from-file=name=name.txt \
    --from-file=surname=surname.txt \
    --from-file=region=region.txt
    