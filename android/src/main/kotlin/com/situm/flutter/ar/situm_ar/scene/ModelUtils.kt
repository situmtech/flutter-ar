package com.situm.flutter.ar.situm_ar.scene

import io.github.sceneview.SceneView
import io.github.sceneview.node.ModelNode
import io.github.sceneview.node.Node

data class SitumARModel (
    val fence:String,
    val name:String,
    val modelNode: ModelNode
){
    // removes model but keeps it
    fun removeFromScene(sceneView: SceneView){
        sceneView.removeChildNode(modelNode)
    }



}


class ModelUtils {
}