/*
 * Copyright (c) 2018 WSO2 Inc. (http:www.wso2.org) All Rights Reserved.
 *
 * WSO2 Inc. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http:www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package main

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/cellery-io/sdk/components/cli/pkg/commands"
)

var isSpinning = true
var isFirstPrint = true
var tag string
var fileName string

func newBuildCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "build CELL_FILE_NAME -t [REPOSITORY]/ORGANIZATION/IMAGE_NAME:VERSION",
		Short: "Build an immutable cell image with required dependencies",
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) == 0 {
				fmt.Printf("'cellery build' requires exactly 2 arguments.\n" +
					"See 'cellery build --help' for more infomation.\n")
				return nil
			}
			fileName = args[0]
			err := commands.RunBuild(tag, fileName)
			if err != nil {
				cmd.Help()
				return err
			}
			return nil
		},
		Example: "  cellery build my-project.bal -t [repo]/org/myproject:1.0.0",
	}
	cmd.Flags().StringVarP(&tag, "tag", "t", "", "[repository]/organization/image_name:version")
	return cmd
}
