kubectl create secret generic gh-credentials \
    --from-file=username=username.txt \
    --from-file=token=token.txt \
    --from-file=repository=repository.txt
