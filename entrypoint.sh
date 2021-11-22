#!/bin/bash
set -e

cd "${INPUT_CODE_PATH}"

install_zip_dependencies(){
	echo "Installing and zipping dependencies..."
	mkdir python
	pip install --target=python -r "${INPUT_REQUIREMENTS_TXT}"
	zip -r dependencies.zip ./python
}

publish_dependencies_as_layer(){
	echo "Publishing dependencies as a layer..."
	local result=$(aws lambda publish-layer-version --layer-name "${INPUT_LAMBDA_LAYER_ARN}" --compatible-runtimes ${INPUT_RUNTIMES} --compatible-architectures ${INPUT_ARCHITECTURES} --zip-file fileb://dependencies.zip)
	LAYER_VERSION=$(jq '.Version' <<< "$result")
	rm -rf python
	rm dependencies.zip
}

publish_function_code(){
	echo "Deploying the code itself..."
	zip -r code.zip . -x \*.git\*
  aws s3 cp code.zip s3://${INPUT_S3_BUCKET}/${INPUT_LAMBDA_FUNCTION_NAME}.zip
	aws lambda update-function-code --architectures ${INPUT_ARCHITECTURES} --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --zip-file fileb://code.zip
}

update_function_layers(){
	echo "Using the layer in the function..."
	aws lambda update-function-configuration --function-name "${INPUT_LAMBDA_FUNCTION_NAME}" --runtime "${INPUT_RUNTIMES%% *}" --layers "${INPUT_LAMBDA_LAYER_ARN}:${LAYER_VERSION}"
}

deploy_lambda_function(){
	[ -n "$INPUT_LAMBDA_LAYER_ARN" ] && install_zip_dependencies && publish_dependencies_as_layer
	[ -n "$INPUT_LAMBDA_FUNCTION_NAME" ] && publish_function_code
	[ -n "$INPUT_LAMBDA_LAYER_ARN" ] && [ -n "$INPUT_LAMBDA_FUNCTION_NAME" ] && update_function_layers
  true
}

deploy_lambda_function
echo "Done."
