package com.situm.flutter.ar.situm_ar.scene

import android.content.Context
import android.graphics.Color
import android.view.Gravity
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.view.isVisible
import androidx.core.view.setMargins
import androidx.core.view.setPadding

class DebugInfo(private var context: Context, private var sceneHandler: ARSceneHandler) :
    FrameLayout(context) {

    private var textView: TextView
    private var buttonContainer: LinearLayout
    private var toggleButton: Button

    init {
        this.apply {
            layoutParams = LayoutParams(
                LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(Color.TRANSPARENT) // Fondo transparente
        }

        // Crear el TextView
        textView = TextView(context).apply {
            text = ""
            textSize = 16f
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#80000000")) // Fondo semitransparente
            gravity = Gravity.LEFT
            layoutParams = LayoutParams(
                LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT
            ).apply {
                //gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL // Posiciona el texto
                topMargin = 50
                leftMargin = 50
            }
        }

        this.addView(textView)
        buttonContainer = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LayoutParams(
                LayoutParams.WRAP_CONTENT,
                LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM or Gravity.END // Ubicación: esquina inferior derecha
            ).apply {
                marginEnd = 30 // Margen derecho
                bottomMargin = 30 // Margen inferior
                setPadding(20)
            }

            // Añadir botones al contenedor
            val button1 = createButton("Redraw World") {
                sceneHandler.worldRedraw()
            }
            val button2 = createButton("Update Arrow") {
                sceneHandler.updateArrowTarget()
            }
            val button3 = createButton("Show Route") {
                sceneHandler.switchShowRouteOnAR()
            }

            this.addView(button1)
            this.addView(button2)
            this.addView(button3)
        }
        this.addView(buttonContainer)

        // Crear el botón grande en la esquina superior derecha
        toggleButton = Button(context).apply {
            text = "Toggle Visibility"
            textSize = 18f
            setBackgroundColor(Color.parseColor("#FF6200EE"))
            setTextColor(Color.WHITE)

            layoutParams = LayoutParams(
                LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = 30
                marginEnd = 30
                gravity = Gravity.RIGHT
            }

            // Detectar el evento de "long press"
            setOnLongClickListener {
                toggleVisibility()
                true  // Retorna true para indicar que el evento se ha consumido
            }
        }
        this.addView(toggleButton)

        makeInvisible()

    }

    private fun makeVisible() {
        sceneHandler.setDebugMode(true)
        buttonContainer.apply { visibility = VISIBLE }
        textView.apply { visibility = VISIBLE }
        toggleButton.apply {
            setBackgroundColor(Color.WHITE)
            setTextColor(Color.BLUE)
        }
    }

    private fun makeInvisible() {
        sceneHandler.setDebugMode(false)
        buttonContainer.apply { visibility = INVISIBLE }
        textView.apply { visibility = INVISIBLE }
        toggleButton.apply {
            setBackgroundColor(Color.TRANSPARENT)
            setTextColor(Color.TRANSPARENT)
        }
    }

    private fun toggleVisibility() {
        if (buttonContainer.isVisible) {
            makeInvisible()
        } else {
            makeVisible()
        }
    }

    private fun createButton(text: String, onClick: () -> Unit): Button {
        return Button(context).apply {
            this.text = text
            textSize = 16f
            //setBackgroundColor(Color.parseColor("#FF6200EE")) // Color del botón
            setBackgroundColor(Color.WHITE)
            setTextColor(Color.BLUE)
            setPadding(10, 10, 10, 10)

            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            )
            (layoutParams as LinearLayout.LayoutParams).setMargins(10)
            setOnClickListener { onClick() }
        }
    }

    fun updateText(text: String) {
        textView.text = text
    }
}